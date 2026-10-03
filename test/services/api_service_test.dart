import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mainapp/services/api_service.dart';
import '../helpers/mocks.dart';

void main() {
  late InMemorySecureStorage storage;

  setUp(() {
    storage = InMemorySecureStorage();
  });

  group("401 interceptor behavior", () {
    test("does NOT clear tokens when refresh fails with network error",
        () async {
      await storage.saveTokens(access: "valid_access", refresh: "valid_refresh");

      final dio = buildAuthDio(storage);
      final adapter = MockAdapter();
      dio.httpClientAdapter = adapter;

      bool refreshFailed = false;
      adapter.handler = (options) {
        if (options.path.contains("refresh")) {
          refreshFailed = true;
          // network error → no response, just throw
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: "Connection refused",
          );
        }
        return MockData({}, 401);
      };

      try {
        await dio.get("/api/auth/me/");
      } catch (_) {}

      // Tokens preserved despite network error during refresh
      expect(await storage.getAccessToken(), "valid_access");
      expect(await storage.getRefreshToken(), "valid_refresh");
      expect(refreshFailed, true);
    });

    test("clears tokens when refresh returns 401 (refresh token expired)",
        () async {
      await storage.saveTokens(access: "old_access", refresh: "expired_refresh");

      final dio = buildAuthDio(storage);
      final adapter = MockAdapter();
      dio.httpClientAdapter = adapter;

      adapter.handler = (options) {
        if (options.path.contains("refresh")) {
          return MockData({"detail": "Token is invalid or expired"}, 401);
        }
        return MockData({}, 401);
      };

      try {
        await dio.get("/api/auth/me/");
      } catch (_) {}

      // Tokens cleared because refresh token is invalid
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });

    test("refreshes token and retries original request on 401", () async {
      await storage.saveTokens(access: "expired_token", refresh: "valid_refresh");

      final dio = buildAuthDio(storage);
      final adapter = MockAdapter();
      dio.httpClientAdapter = adapter;

      int callCount = 0;
      adapter.handler = (options) {
        callCount++;
        if (options.path.contains("refresh")) {
          return MockData({"access": "new_access_token"}, 200);
        }
        if (callCount == 1) {
          return MockData({}, 401);
        }
        return MockData({"email": "user@test.com"}, 200);
      };

      final response = await dio.get("/api/auth/me/");
      expect(response.statusCode, 200);
      expect((response.data as Map)["email"], "user@test.com");
      expect(await storage.getAccessToken(), "new_access_token");
    });
  });
}
