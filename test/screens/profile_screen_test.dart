import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mainapp/providers/auth_provider.dart';
import 'package:mainapp/screens/profile_screen.dart';
import 'package:mainapp/services/auth_service.dart';
import 'package:mainapp/services/secure_storage.dart';
import '../helpers/mocks.dart';

void main() {
  Future<AuthProvider> setupAuthenticatedProvider(WidgetTester tester) async {
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
    return provider;
  }

  group("ProfileScreen", () {
    testWidgets("renders profile screen with user info", (tester) async {
      final provider = await setupAuthenticatedProvider(tester);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: provider),
            ChangeNotifierProvider(create: (_) => mockTweetProvider()),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.textContaining("test@test.com"), findsAtLeastNWidgets(1));
      expect(find.text("testuser"), findsAtLeastNWidgets(1));
    });

    testWidgets("shows settings icon in app bar", (tester) async {
      final provider = await setupAuthenticatedProvider(tester);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: provider),
            ChangeNotifierProvider(create: (_) => mockTweetProvider()),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });
  });
}
