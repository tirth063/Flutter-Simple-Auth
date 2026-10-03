import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AuthEvent {
  tokenIssued,
  tokenRefreshed,
  refreshFailed,
  tokenCleared,
}

int? getTokenExpiry(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final data = jsonDecode(payload) as Map<String, dynamic>;
    return data['exp'] as int?;
  } catch (_) {
    return null;
  }
}

class SecureStorage {
  final _storage = const FlutterSecureStorage();

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: "access_token", value: access);
    await _storage.write(key: "refresh_token", value: refresh);
  }

  Future<void> saveAccessToken(String access) async {
    await _storage.write(key: "access_token", value: access);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: "access_token");
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: "refresh_token");
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
