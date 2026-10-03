import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mainapp/config/api_config.dart';
import 'package:mainapp/providers/auth_provider.dart';
import 'package:mainapp/services/secure_storage.dart';

class AuthStatusScreen extends StatefulWidget {
  const AuthStatusScreen({super.key});

  @override
  State<AuthStatusScreen> createState() => _AuthStatusScreenState();
}

class _AuthStatusScreenState extends State<AuthStatusScreen> {
  final List<_AuthLogEntry> _log = [];
  late final VoidCallback _onEvent;
  AuthProvider? _auth;
  Timer? _countdownTimer;
  DateTime? _tokenExpiry;
  String? _testApiResult;
  bool _isTestingApi = false;
  bool _isRefreshing = false;
  bool _autoRefreshScheduled = false;
  bool _isForceExpiring = false;

  @override
  void initState() {
    super.initState();
    _onEvent = _handleEvent;
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _auth?.eventNotifier.removeListener(_onEvent);
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _handleEvent() {
    final auth = _auth;
    if (auth == null) return;
    final event = auth.eventNotifier.value;
    if (event == null) return;
    final msg = switch (event) {
      AuthEvent.tokenIssued => "Token issued",
      AuthEvent.tokenRefreshed => "Token refreshed",
      AuthEvent.refreshFailed => "Refresh failed",
      AuthEvent.tokenCleared => "Token cleared",
    };
    _addLogEntry(msg, _eventColor(event));
    if (event == AuthEvent.tokenIssued ||
        event == AuthEvent.tokenRefreshed) {
      _setRefreshing(false);
      _refreshTokenInfo();
    } else if (event == AuthEvent.tokenCleared) {
      setState(() {
        _tokenExpiry = null;
        _autoRefreshScheduled = false;
      });
    }
  }

  Future<void> _init() async {
    _auth = context.read<AuthProvider>();
    _auth!.eventNotifier.addListener(_onEvent);
    final storage = SecureStorage();
    final access = await storage.getAccessToken();
    if (access != null) {
      _decodeAndLogToken(access, "Token loaded from storage");
      _checkAutoRefreshScheduled(access);
    }
    _refreshTokenInfo();
  }

  void _checkAutoRefreshScheduled(String token) {
    final exp = getTokenExpiry(token);
    if (exp == null) return;
    final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    final refreshAt = expiryTime.subtract(const Duration(seconds: 15));
    setState(() {
      _autoRefreshScheduled = refreshAt.isAfter(DateTime.now());
    });
  }

  void _setRefreshing(bool value) {
    setState(() => _isRefreshing = value);
  }

  Color _eventColor(AuthEvent event) {
    return switch (event) {
      AuthEvent.tokenIssued => Colors.green,
      AuthEvent.tokenRefreshed => Colors.blue,
      AuthEvent.refreshFailed => Colors.red,
      AuthEvent.tokenCleared => Colors.orange,
    };
  }

  void _addLogEntry(String message, Color color) {
    final now = DateTime.now();
    final time =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    setState(() {
      _log.insert(
          0, _AuthLogEntry(time: time, message: message, color: color));
      if (_log.length > 50) _log.removeLast();
    });
  }

  Future<void> _refreshTokenInfo() async {
    final storage = SecureStorage();
    final token = await storage.getAccessToken();
    if (token != null) {
      _decodeAndLogToken(token, null);
      _checkAutoRefreshScheduled(token);
      _startCountdown();
    }
  }

  void _decodeAndLogToken(String token, String? logMessage) {
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = utf8.decode(
          base64Url.decode(base64Url.normalize(parts[1])),
        );
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final exp = data['exp'] as int?;
        if (exp != null) {
          _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        }
        if (logMessage != null) {
          final expStr = _tokenExpiry != null
              ? " (expires at ${_tokenExpiry!.hour.toString().padLeft(2, '0')}:${_tokenExpiry!.minute.toString().padLeft(2, '0')}:${_tokenExpiry!.second.toString().padLeft(2, '0')})"
              : "";
          _addLogEntry("$logMessage$expStr", Colors.green);
        }
      }
    } catch (_) {}
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Duration? get _timeUntilExpiry {
    if (_tokenExpiry == null) return null;
    return _tokenExpiry!.difference(DateTime.now());
  }

  Future<void> _forceExpireToken() async {
    if (_isForceExpiring) return;
    _isForceExpiring = true;
    try {
      final storage = SecureStorage();
      final expiredToken =
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
          "eyJleHAiOjE2MDAwMDAwMDB9."
          "abc123";
      await storage.saveAccessToken(expiredToken);
      _addLogEntry("Token force-expired (fake token saved)", Colors.red);
      setState(() {
        _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(1600000000000);
        _autoRefreshScheduled = false;
      });
      await _testProtectedApi();
    } finally {
      _isForceExpiring = false;
    }
  }

  Future<void> _testProtectedApi() async {
    if (_isTestingApi) return;
    setState(() => _isTestingApi = true);
    final auth = _auth;
    if (auth == null) {
      if (mounted) setState(() => _isTestingApi = false);
      return;
    }
    try {
      final response = await auth.dio.get(ApiConfig.protectedUrl);
      if (!mounted) return;
      setState(() {
        _testApiResult =
            "Status: ${response.statusCode}\n${response.data}";
      });
      _addLogEntry("Protected API: ${response.statusCode}", Colors.green);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testApiResult = "Error: $e";
      });
      _addLogEntry(
          "Protected API failed: ${e.toString().substring(0, 80)}",
          Colors.red);
    } finally {
      if (mounted) setState(() => _isTestingApi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final timeLeft = _timeUntilExpiry;

    Color statusColor;
    String statusText;
    if (!auth.isAuthenticated) {
      statusColor = Colors.red;
      statusText = "No Token";
    } else if (_isRefreshing) {
      statusColor = Colors.blue;
      statusText = "Refreshing...";
    } else if (timeLeft != null && timeLeft.isNegative) {
      statusColor = Colors.red;
      statusText = "Token Expired";
    } else if (timeLeft != null && timeLeft.inSeconds < 30) {
      statusColor = Colors.orange;
      statusText = "About to expire";
    } else {
      statusColor = Colors.green;
      statusText = "Token Valid";
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Auth Status"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusBadge(color: statusColor, text: statusText),
          const SizedBox(height: 16),
          _TokenInfoCard(
            title: "Access Token",
            getToken: () async =>
                _maskToken((await SecureStorage().getAccessToken()) ?? "N/A"),
          ),
          const SizedBox(height: 8),
          _TokenInfoCard(
            title: "Refresh Token",
            getToken: () async =>
                _maskToken((await SecureStorage().getRefreshToken()) ?? "N/A"),
          ),
          if (_autoRefreshScheduled && timeLeft != null && !timeLeft.isNegative) ...[
            const SizedBox(height: 8),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Auto-refresh scheduled in ${timeLeft.inSeconds > 15 ? (timeLeft.inSeconds - 15).toString() : "0"}s",
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (timeLeft != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text("Token Expiry",
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      timeLeft.isNegative
                          ? "EXPIRED"
                          : "${timeLeft.inMinutes}:${(timeLeft.inSeconds % 60).toString().padLeft(2, '0')}",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: timeLeft.isNegative
                            ? Colors.red
                            : timeLeft.inSeconds < 30
                                ? Colors.orange
                                : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _forceExpireToken,
                  icon: const Icon(Icons.timer_off),
                  label: const Text("Force Expire"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                    foregroundColor: Colors.red.shade900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isTestingApi ? null : _testProtectedApi,
                  icon: _isTestingApi
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.api),
                  label: const Text("Test API"),
                ),
              ),
            ],
          ),
          if (_testApiResult != null) ...[
            const SizedBox(height: 8),
            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _testApiResult!,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text("Auth Event Log",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          ..._log.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(entry.time,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontFamily: 'monospace')),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: entry.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(entry.message,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _maskToken(String token) {
    if (token.length <= 12) return token;
    return "${token.substring(0, 6)}...${token.substring(token.length - 6)}";
  }
}

class _StatusBadge extends StatelessWidget {
  final Color color;
  final String text;

  const _StatusBadge({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TokenInfoCard extends StatelessWidget {
  final String title;
  final Future<String> Function() getToken;

  const _TokenInfoCard({
    required this.title,
    required this.getToken,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 4),
            FutureBuilder<String>(
              future: getToken(),
              builder: (context, snapshot) {
                return Text(
                  snapshot.data ?? "Loading...",
                  style: const TextStyle(
                      fontSize: 13, fontFamily: 'monospace'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthLogEntry {
  final String time;
  final String message;
  final Color color;

  _AuthLogEntry({
    required this.time,
    required this.message,
    required this.color,
  });
}
