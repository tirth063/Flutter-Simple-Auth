import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mainapp/services/auth_service.dart';
import 'package:mainapp/services/secure_storage.dart';
import '../helpers/mocks.dart';

void main() {
  late Dio dio;
  late MockInterceptor interceptor;
  late SecureStorage storage;
  late AuthService authService;

  setUp(() {
    interceptor = MockInterceptor();
    dio = Dio(BaseOptions(baseUrl: "http://test.com"))
      ..interceptors.add(interceptor);
    storage = InMemorySecureStorage();
    authService = AuthService(dio: dio, storage: storage);
  });

  group("AuthService - login", () {
    test("should save tokens on success", () async {
      interceptor.handler = (options) {
        return MockData({
          "tokens": {"access": "access_123", "refresh": "refresh_456"},
          "user": {"id": 1, "email": "test@test.com", "role": "user", "permissions": []},
        }, 200);
      };

      final result = await authService.login(
        email: "test@test.com",
        password: "pass123",
      );
      expect(result, isNotNull);
      expect(result!["tokens"]["access"], "access_123");
      expect(await storage.getAccessToken(), "access_123");
      expect(await storage.getRefreshToken(), "refresh_456");
    });

    test("should throw on 401 with detail message", () async {
      interceptor.handler = (options) {
        throw DioException(
          requestOptions: RequestOptions(path: options.path),
          response: Response(
            requestOptions: RequestOptions(path: options.path),
            statusCode: 401,
            data: {"detail": "Invalid email or password."},
          ),
        );
      };

      expect(
        () => authService.login(email: "wrong@test.com", password: "wrong"),
        throwsA(predicate((e) => e.toString().contains("Invalid email or password"))),
      );
    });

    test("should throw connection error message on timeout", () async {
      interceptor.handler = (options) {
        throw DioException(
          requestOptions: RequestOptions(path: options.path),
          type: DioExceptionType.connectionTimeout,
        );
      };

      expect(
        () => authService.login(email: "test@test.com", password: "pass"),
        throwsA(predicate((e) => e.toString().contains("timed out"))),
      );
    });

    test("should throw connection error message on connectionError", () async {
      interceptor.handler = (options) {
        throw DioException(
          requestOptions: RequestOptions(path: options.path),
          type: DioExceptionType.connectionError,
        );
      };

      expect(
        () => authService.login(email: "test@test.com", password: "pass"),
        throwsA(predicate((e) => e.toString().contains("Cannot reach server"))),
      );
    });
  });

  group("AuthService - register", () {
    test("should save tokens on success", () async {
      interceptor.handler = (options) {
        return MockData({
          "tokens": {"access": "acc_reg", "refresh": "ref_reg"},
          "user": {"id": 2, "email": "new@test.com", "role": "user", "permissions": []},
        }, 201);
      };

      final result = await authService.register(
        email: "new@test.com",
        username: "newuser",
        password: "pass1234",
        passwordConfirm: "pass1234",
      );
      expect(result, isNotNull);
      expect(await storage.getAccessToken(), "acc_reg");
    });

    test("should extract field-level error on 400", () async {
      interceptor.handler = (options) {
        throw DioException(
          requestOptions: RequestOptions(path: options.path),
          response: Response(
            requestOptions: RequestOptions(path: options.path),
            statusCode: 400,
            data: {"password": ["This password is too short."]},
          ),
        );
      };

      expect(
        () => authService.register(
          email: "a@b.com",
          username: "u",
          password: "short",
          passwordConfirm: "short",
        ),
        throwsA(predicate((e) => e.toString().contains("too short"))),
      );
    });
  });

  group("AuthService - refreshToken", () {
    test("should return null when no refresh token stored", () async {
      final result = await authService.refreshToken();
      expect(result, isNull);
    });

    test("should return new access token on success", () async {
      await storage.saveTokens(access: "old_access", refresh: "refresh_token");
      interceptor.handler = (options) {
        return MockData({"access": "new_access_token"}, 200);
      };

      final result = await authService.refreshToken();
      expect(result, "new_access_token");
      expect(await storage.getAccessToken(), "new_access_token");
    });

    test("should return null on refresh failure", () async {
      await storage.saveTokens(access: "old_access", refresh: "bad_refresh");
      interceptor.handler = (options) {
        throw DioException(
          requestOptions: RequestOptions(path: options.path),
          type: DioExceptionType.connectionError,
        );
      };

      final result = await authService.refreshToken();
      expect(result, isNull);
    });

    test("should clear all tokens on 401 from refresh", () async {
      await storage.saveTokens(access: "old", refresh: "bad");
      interceptor.handler = (options) {
        throw DioException(
          requestOptions: RequestOptions(path: options.path),
          response: Response(
            requestOptions: RequestOptions(path: options.path),
            statusCode: 401,
          ),
        );
      };

      final result = await authService.refreshToken();
      expect(result, isNull);
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });
  });

  group("AuthService - logout", () {
    test("should clear tokens", () async {
      await storage.saveTokens(access: "a", refresh: "r");
      interceptor.handler = (options) {
        return MockData({"message": "Logout successful."}, 200);
      };
      await authService.logout();
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });

    test("should clear tokens even if logout request fails", () async {
      await storage.saveTokens(access: "a", refresh: "r");
      interceptor.handler = (options) {
        throw DioException(
          requestOptions: RequestOptions(path: options.path),
          type: DioExceptionType.connectionError,
        );
      };
      await authService.logout();
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });
  });
}
