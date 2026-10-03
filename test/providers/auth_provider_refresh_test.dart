import 'package:flutter_test/flutter_test.dart';

import 'package:dio/dio.dart';
import 'package:mainapp/providers/auth_provider.dart';
import 'package:mainapp/services/auth_service.dart';
import 'package:mainapp/services/secure_storage.dart';
import '../helpers/mocks.dart';

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

  group("AuthProvider - auth events", () {
    test("eventNotifier emits tokenIssued on successful login", () async {
      AuthEvent? emitted;
      authProvider.eventNotifier.addListener(() {
        emitted = authProvider.eventNotifier.value;
      });

      interceptor.handler = (options) {
        return MockData({
          "tokens": {"access": "acc", "refresh": "ref"},
          "user": {"id": 1, "email": "a@b.com"},
        }, 200);
      };

      await authProvider.login(email: "a@b.com", password: "pass");
      expect(emitted, AuthEvent.tokenIssued);
    });

    test("eventNotifier emits tokenCleared on logout", () async {
      await storage.saveTokens(access: "a", refresh: "r");
      interceptor.handler = (options) {
        if (options.path.contains("/me")) {
          return MockData({"id": 1, "email": "x@x.com", "username": "x"}, 200);
        }
        return MockData({"message": "ok"}, 200);
      };
      await authProvider.loadToken();

      AuthEvent? emitted;
      authProvider.eventNotifier.addListener(() {
        emitted = authProvider.eventNotifier.value;
      });

      interceptor.handler = (options) {
        return MockData({"message": "ok"}, 200);
      };

      await authProvider.logout();
      expect(emitted, AuthEvent.tokenCleared);
    });

    test("eventNotifier is null initially", () {
      expect(authProvider.eventNotifier.value, isNull);
    });
  });
}
