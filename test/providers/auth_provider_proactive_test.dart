import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mainapp/providers/auth_provider.dart';
import 'package:mainapp/services/auth_service.dart';
import 'package:mainapp/services/secure_storage.dart';
import 'dart:convert';
import '../helpers/mocks.dart';

String _encodePayload(Map<String, dynamic> payload) {
  final json = jsonEncode(payload);
  return base64Url.encode(utf8.encode(json)).replaceAll('=', '');
}

void main() {
  late Dio dio;
  late MockInterceptor interceptor;
  late SecureStorage storage;
  late AuthService authService;
  late AuthProvider authProvider;

  setUp(() {
    interceptor = MockInterceptor();
    dio = Dio(BaseOptions(baseUrl: "http://test.com"))
      ..interceptors.add(interceptor);
    storage = InMemorySecureStorage();
    authService = AuthService(dio: dio, storage: storage);
    authProvider = AuthProvider(
      authService: authService,
      storage: storage,
    );
  });

  group("AuthProvider - proactive refresh", () {
    test("login schedules proactive refresh and emits tokenIssued", () async {
      final futureExp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 120;
      final accessToken =
          "eyJhbGciOiJIUzI1NiJ9.${_encodePayload({"exp": futureExp, "user_id": 1})}.sig";

      interceptor.handler = (options) {
        return MockData({
          "tokens": {"access": accessToken, "refresh": "ref_token"},
          "user": {"id": 1, "email": "a@b.com"},
        }, 200);
      };

      AuthEvent? emitted;
      authProvider.eventNotifier.addListener(() {
        emitted = authProvider.eventNotifier.value;
      });

      await authProvider.login(email: "a@b.com", password: "pass");

      expect(authProvider.isAuthenticated, true);
      expect(emitted, AuthEvent.tokenIssued);
    });

    test("cancelProactiveRefresh stops the timer", () async {
      authProvider.cancelProactiveRefresh();

      interceptor.handler = (options) {
        return MockData({
          "tokens": {"access": "tok", "refresh": "ref"},
          "user": {"id": 1, "email": "a@b.com"},
        }, 200);
      };

      await authProvider.login(email: "a@b.com", password: "pass");
      authProvider.cancelProactiveRefresh();
    });

    test("refreshToken via AuthService saves new access token", () async {
      await storage.saveTokens(access: "old_access", refresh: "refresh_tok");

      interceptor.handler = (options) {
        return MockData({"access": "new_access_token"}, 200);
      };

      final result = await authService.refreshToken();
      expect(result, "new_access_token");
      expect(await storage.getAccessToken(), "new_access_token");
    });

    test("logout cancels proactive refresh and clears tokens", () async {
      await storage.saveTokens(access: "a", refresh: "r");
      interceptor.handler = (options) {
        if (options.path.contains("/me")) {
          return MockData({"id": 1, "email": "x@x.com", "username": "x"}, 200);
        }
        return MockData({"message": "ok"}, 200);
      };
      await authProvider.loadToken();
      expect(authProvider.isAuthenticated, true);

      interceptor.handler = (options) {
        return MockData({"message": "ok"}, 200);
      };

      await authProvider.logout();
      expect(authProvider.isAuthenticated, false);
      expect(await storage.getAccessToken(), isNull);
    });
  });
}
