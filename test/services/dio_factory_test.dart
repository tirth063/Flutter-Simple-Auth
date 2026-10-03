import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mainapp/services/api_service.dart';

import '../helpers/mocks.dart';

void main() {
  late InMemorySecureStorage storage;
  late Dio dio;

  setUp(() {
    storage = InMemorySecureStorage();
    dio = buildAuthDio(storage);
  });

  group("buildAuthDio", () {
    test("creates Dio with base URL configured", () {
      expect(dio.options.baseUrl, "http://localhost:8000");
      expect(dio.options.connectTimeout, const Duration(seconds: 15));
      expect(dio.options.receiveTimeout, const Duration(seconds: 15));
      expect(dio.options.headers["Content-Type"], "application/json");
    });

    test("returns a Dio instance", () {
      expect(dio, isA<Dio>());
      expect(dio.interceptors.length, greaterThan(0));
    });

    test("interceptor attaches token from storage on request", () async {
      await storage.saveTokens(access: "test_token_abc", refresh: "refresh");
      String? capturedHeader;

      final testDio = Dio(BaseOptions(baseUrl: "http://test.com"));
      testDio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedHeader = options.headers["Authorization"] as String?;
          handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
          ));
        },
      ));

      await storage.getAccessToken(); // warm up
      final authDio = buildAuthDio(storage);
      authDio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedHeader = options.headers["Authorization"] as String?;
          handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
          ));
        },
      ));

      try {
        await authDio.get("/test");
      } catch (_) {}
      expect(capturedHeader, "Bearer test_token_abc");
    });
  });
}
