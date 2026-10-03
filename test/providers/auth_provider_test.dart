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
    authProvider = AuthProvider(authService: authService, storage: storage);
  });

  group("AuthProvider - loadToken", () {
    test("should be unauthenticated when no token stored", () async {
      expect(authProvider.status, AuthStatus.initial);
      await authProvider.loadToken();
      expect(authProvider.status, AuthStatus.unauthenticated);
    });

    test("should be authenticated when token is stored", () async {
      await storage.saveTokens(access: "test_access", refresh: "test_refresh");
      interceptor.handler = (options) {
        if (options.path.contains("/me")) {
          return MockData({
            "id": 1,
            "email": "test@test.com",
            "username": "testuser",
            "role": "user",
            "permissions": ["TWEET_CREATE", "TWEET_VIEW"],
          }, 200);
        }
        return MockData({}, 401);
      };
      await authProvider.loadToken();
      expect(authProvider.status, AuthStatus.authenticated);
      expect(authProvider.user!["role"], "user");
    });
  });

  group("AuthProvider - login", () {
    test("should authenticate on successful login", () async {
      interceptor.handler = (options) {
        return MockData({
          "tokens": {"access": "new_access", "refresh": "new_refresh"},
          "user": {
            "id": 1,
            "email": "test@test.com",
            "username": "testuser",
            "role": "user",
            "permissions": ["TWEET_CREATE", "TWEET_VIEW", "TWEET_SHARE"],
          },
        }, 200);
      };

      await authProvider.login(email: "test@test.com", password: "password123");
      expect(authProvider.status, AuthStatus.authenticated);
      expect(authProvider.user!["email"], "test@test.com");
      expect(authProvider.user!["role"], "user");
    });

    test("should fail on 401 response", () async {
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

      await expectLater(
        () => authProvider.login(email: "wrong@test.com", password: "wrong"),
        throwsA(isA<Exception>()),
      );
      expect(authProvider.status, AuthStatus.unauthenticated);
    });
  });

  group("AuthProvider - permissions", () {
    test("hasPermission returns true when permission exists", () async {
      interceptor.handler = (options) {
        return MockData({
          "tokens": {"access": "acc", "refresh": "ref"},
          "user": {
            "id": 1,
            "email": "a@b.com",
            "role": "admin",
            "permissions": ["TWEET_CREATE", "TWEET_VIEW", "USER_BAN"],
          },
        }, 200);
      };

      await authProvider.login(email: "a@b.com", password: "pass");
      expect(authProvider.hasPermission("TWEET_CREATE"), true);
      expect(authProvider.hasPermission("USER_BAN"), true);
      expect(authProvider.hasPermission("FAKE_PERM"), false);
    });

    test("hasPermission returns false when not authenticated", () {
      expect(authProvider.hasPermission("TWEET_CREATE"), false);
    });

    test("hasPermission returns false when user has empty permissions", () async {
      interceptor.handler = (options) {
        return MockData({
          "tokens": {"access": "acc", "refresh": "ref"},
          "user": {
            "id": 1,
            "email": "a@b.com",
            "role": "user",
            "permissions": [],
          },
        }, 200);
      };

      await authProvider.login(email: "a@b.com", password: "pass");
      expect(authProvider.hasPermission("TWEET_CREATE"), false);
    });
  });

  group("AuthProvider - logout", () {
    test("should clear state on logout", () async {
      await storage.saveTokens(access: "a", refresh: "r");
      interceptor.handler = (options) {
        if (options.path.contains("/me")) {
          return MockData({"id": 1, "email": "x@x.com", "username": "x", "role": "user", "permissions": []}, 200);
        }
        return MockData({"message": "Logout successful."}, 200);
      };
      await authProvider.loadToken();
      expect(authProvider.isAuthenticated, true);

      interceptor.handler = (options) {
        return MockData({"message": "Logout successful."}, 200);
      };

      await authProvider.logout();
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.user, isNull);
      expect(await storage.getAccessToken(), isNull);
    });
  });
}
