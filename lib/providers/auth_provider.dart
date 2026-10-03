import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mainapp/services/auth_service.dart';
import 'package:mainapp/services/secure_storage.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final SecureStorage _storage;
  final ValueNotifier<AuthEvent?> _eventNotifier;
  AuthStatus _status = AuthStatus.initial;
  Map<String, dynamic>? _user;
  String? _errorMessage;
  Timer? _refreshTimer;
  int _refreshBackoffSeconds = 15;

  AuthProvider({
    AuthService? authService,
    SecureStorage? storage,
    ValueNotifier<AuthEvent?>? eventNotifier,
    void Function(AuthEvent)? onEvent,
  })  : _authService = authService ?? AuthService(onEvent: onEvent),
        _storage = storage ?? SecureStorage(),
        _eventNotifier = eventNotifier ?? ValueNotifier(null) {
    _eventNotifier.addListener(_onEventNotifierChanged);
  }

  @override
  void dispose() {
    _eventNotifier.removeListener(_onEventNotifierChanged);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onEventNotifierChanged() {
    final event = _eventNotifier.value;
    if (event == null) return;
    switch (event) {
      case AuthEvent.tokenCleared:
        _status = AuthStatus.unauthenticated;
        _user = null;
        _refreshTimer?.cancel();
        notifyListeners();
      case AuthEvent.tokenRefreshed:
        _refreshBackoffSeconds = 15;
        _storage.getAccessToken().then((token) {
          if (token != null) _scheduleProactiveRefresh(token);
        });
      default:
        break;
    }
  }

  AuthStatus get status => _status;
  Map<String, dynamic>? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  ValueNotifier<AuthEvent?> get eventNotifier => _eventNotifier;
  Dio get dio => _authService.dio;

  void _emitEvent(AuthEvent event) {
    _eventNotifier.value = event;
  }

  bool hasPermission(String code) {
    if (_user == null) return false;
    final perms = _user!['permissions'] as List<dynamic>? ?? [];
    return perms.contains(code);
  }

  void _scheduleProactiveRefresh(String accessToken) {
    _refreshTimer?.cancel();
    final exp = getTokenExpiry(accessToken);
    if (exp == null) return;
    final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    final now = DateTime.now();
    if (expiryTime.isBefore(now)) {
      _proactiveRefresh();
      return;
    }
    final refreshAt = expiryTime.subtract(const Duration(seconds: 15));
    var delay = refreshAt.difference(now);
    if (delay.isNegative) {
      _proactiveRefresh();
      return;
    }
    const maxDelay = Duration(days: 20);
    if (delay > maxDelay) {
      delay = maxDelay;
    }
    _refreshTimer = Timer(delay, _proactiveRefresh);
  }

  void cancelProactiveRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _proactiveRefresh() async {
    final result = await _authService.refreshToken();
    if (result != null) {
      _emitEvent(AuthEvent.tokenRefreshed);
      _scheduleProactiveRefresh(result);
    } else {
      _emitEvent(AuthEvent.refreshFailed);
      final token = await _storage.getAccessToken();
      if (token != null) {
        _refreshTimer?.cancel();
        _refreshTimer = Timer(
          Duration(seconds: _refreshBackoffSeconds),
          _proactiveRefresh,
        );
        _refreshBackoffSeconds = (_refreshBackoffSeconds * 2).clamp(15, 120);
      }
    }
  }

  Future<void> loadToken() async {
    _status = AuthStatus.loading;
    notifyListeners();
    final token = await _storage.getAccessToken();
    if (token != null) {
      _scheduleProactiveRefresh(token);
      try {
        final userData = await _authService.getMe();
        if (userData != null) {
          _user = userData;
          _status = AuthStatus.authenticated;
        } else {
          final activeToken = await _storage.getAccessToken();
          if (activeToken == null) {
            _status = AuthStatus.unauthenticated;
            _user = null;
          } else {
            _status = AuthStatus.authenticated;
          }
        }
      } catch (_) {
        final activeToken = await _storage.getAccessToken();
        if (activeToken == null) {
          _status = AuthStatus.unauthenticated;
          _user = null;
        } else {
          _status = AuthStatus.authenticated;
        }
      }
      notifyListeners();
    } else {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _authService.login(email: email, password: password);
      _user = result!["user"] as Map<String, dynamic>;
      final accessToken = (result["tokens"] as Map)["access"] as String;
      _refreshBackoffSeconds = 15;
      _emitEvent(AuthEvent.tokenIssued);
      _scheduleProactiveRefresh(accessToken);
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String passwordConfirm,
  }) async {
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _authService.register(
        email: email,
        username: username,
        password: password,
        passwordConfirm: passwordConfirm,
      );
      _user = result!["user"] as Map<String, dynamic>;
      final accessToken = (result["tokens"] as Map)["access"] as String;
      _refreshBackoffSeconds = 15;
      _emitEvent(AuthEvent.tokenIssued);
      _scheduleProactiveRefresh(accessToken);
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchUser() async {
    try {
      final user = await _authService.getMe();
      if (user != null) {
        _user = user;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    cancelProactiveRefresh();
    notifyListeners();
    await _authService.logout();
    _user = null;
    _emitEvent(AuthEvent.tokenCleared);
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
