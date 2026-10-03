import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mainapp/app.dart';
import 'package:mainapp/providers/auth_provider.dart';
import 'package:mainapp/screens/splash_screen.dart';
import 'package:mainapp/screens/login_screen.dart';
import 'package:mainapp/screens/feed_screen.dart';
import 'package:mainapp/services/api_service.dart';
import 'package:mainapp/services/auth_service.dart';
import 'package:mainapp/services/secure_storage.dart';
import 'package:mainapp/providers/tweet_provider.dart';
import 'helpers/mocks.dart';

void main() {
  group("App - navigation", () {
    testWidgets("shows SplashScreen on initial status", (tester) async {
      final storage = InMemorySecureStorage();
      final eventNotifier = ValueNotifier<AuthEvent?>(null);
      final dio = buildAuthDio(storage, onEvent: (e) => eventNotifier.value = e);
      final authService = AuthService(dio: dio, storage: storage);

      await tester.pumpWidget(MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthProvider(
                authService: authService,
                storage: storage,
                eventNotifier: eventNotifier,
              ),
            ),
            ChangeNotifierProvider(create: (_) => mockTweetProvider()),
          ],
          child: const App(),
        ),
      ));

      expect(find.byType(SplashScreen), findsOneWidget);
    });

    testWidgets("shows LoginScreen when unauthenticated", (tester) async {
      final storage = InMemorySecureStorage();
      final eventNotifier = ValueNotifier<AuthEvent?>(null);
      final dio = buildAuthDio(storage, onEvent: (e) => eventNotifier.value = e);
      final authService = AuthService(dio: dio, storage: storage);

      final provider = AuthProvider(
        authService: authService,
        storage: storage,
        eventNotifier: eventNotifier,
      );
      await provider.loadToken();

      await tester.pumpWidget(MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider(create: (_) => mockTweetProvider()),
          ],
          child: const App(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets("shows bottom nav when authenticated", (tester) async {
      final storage = InMemorySecureStorage();
      final eventNotifier = ValueNotifier<AuthEvent?>(null);
      final interceptor = MockInterceptor();
      interceptor.handler = (options) {
        if (options.path.contains("/login")) {
          return MockData({
            "user": {
              "id": 1,
              "email": "test@test.com",
              "username": "testuser",
              "role": "user",
              "permissions": [],
              "date_joined": "2025-01-15T10:00:00Z",
            },
            "tokens": {
              "access":
                  "eyJhbGciOiJIUzI1NiJ9.eyJ0b3RhbF9zZWNyZXRfa2V5IjoxLCJ1c2VyX2lkIjoxLCJleHAiOjk5OTk5OTk5OTl9.signature",
              "refresh": "refresh_token_123",
            },
          }, 200);
        }
        return MockData([], 200);
      };
      final dio = Dio(BaseOptions(baseUrl: "http://test.com"))
        ..interceptors.add(interceptor);

      final authService = AuthService(dio: dio, storage: storage);
      final provider = AuthProvider(
        authService: authService,
        storage: storage,
        eventNotifier: eventNotifier,
      );

      await tester.runAsync(() async {
        await provider.login(email: "test@test.com", password: "password");
      });
      provider.cancelProactiveRefresh();

      await tester.pumpWidget(MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider(create: (_) => mockTweetProvider()),
          ],
          child: const App(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(FeedScreen), findsOneWidget);
    });
  });
}
