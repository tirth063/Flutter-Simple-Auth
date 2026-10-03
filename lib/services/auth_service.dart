import 'package:dio/dio.dart';
import 'package:mainapp/config/api_config.dart';
import 'package:mainapp/services/api_service.dart';
import 'package:mainapp/services/secure_storage.dart';

class AuthService {
  final Dio _dio;
  final SecureStorage _storage;

  AuthService({Dio? dio, SecureStorage? storage, void Function(AuthEvent)? onEvent})
      : _dio = dio ?? buildAuthDio(storage ?? SecureStorage(), onEvent: onEvent),
        _storage = storage ?? SecureStorage();

  Dio get dio => _dio;

  String _extractErrorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      if (data.containsKey("detail")) {
        return data["detail"].toString();
      }
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return "Connection timed out. Check your server.";
    }
    if (e.type == DioExceptionType.connectionError) {
      return "Cannot reach server. Is Django running?";
    }
    return fallback;
  }

  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.loginUrl,
        data: {"email": email, "password": password},
      );
      final data = response.data as Map<String, dynamic>;
      final tokens = data["tokens"] as Map<String, dynamic>;
      final accessToken = tokens["access"] as String;
      final refreshToken = tokens["refresh"] as String;
      await _storage.saveTokens(access: accessToken, refresh: refreshToken);
      return data;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, "Invalid email or password."));
    }
  }

  Future<Map<String, dynamic>?> register({
    required String email,
    required String username,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.registerUrl,
        data: {
          "email": email,
          "username": username,
          "password": password,
          "password_confirm": passwordConfirm,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final tokens = data["tokens"] as Map<String, dynamic>;
      final accessToken = tokens["access"] as String;
      final refreshToken = tokens["refresh"] as String;
      await _storage.saveTokens(access: accessToken, refresh: refreshToken);
      return data;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, "Registration failed."));
    }
  }

  Future<String?> refreshToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) return null;
      final response = await _dio.post(
        ApiConfig.refreshUrl,
        data: {"refresh": refreshToken},
      );
      final newAccessToken = response.data["access"] as String;
      final newRefreshToken = response.data["refresh"] as String?;
      if (newRefreshToken != null) {
        await _storage.saveTokens(
          access: newAccessToken,
          refresh: newRefreshToken,
        );
      } else {
        await _storage.saveAccessToken(newAccessToken);
      }
      return newAccessToken;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _storage.clearAll();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken != null) {
        await _dio.post(
          ApiConfig.logoutUrl,
          data: {"refresh": refreshToken},
          options: Options(headers: {"Authorization": null}),
        );
      }
    } catch (_) {}
    await _storage.clearAll();
  }

  Future<Map<String, dynamic>?> getMe() async {
    try {
      final response = await _dio.get(ApiConfig.meUrl);
      return response.data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}
