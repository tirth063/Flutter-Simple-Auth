import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:mainapp/providers/auth_provider.dart';
import 'package:mainapp/screens/settings_screen.dart';
import 'package:mainapp/services/auth_service.dart';
import 'package:mainapp/services/secure_storage.dart';
import '../helpers/mocks.dart';

void main() {
  late Dio dio;
  late MockInterceptor interceptor;
  late SecureStorage storage;

  setUp(() {
    interceptor = MockInterceptor();
    dio = Dio(BaseOptions(baseUrl: "http://test.com"))
      ..interceptors.add(interceptor);
    storage = InMemorySecureStorage();
  });

  group("SettingsScreen", () {
    testWidgets("renders setting tiles", (tester) async {
      final authService = AuthService(dio: dio, storage: storage);
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authService: authService,
            storage: storage,
          ),
          child: const SettingsScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text("Notifications"), findsOneWidget);
      expect(find.text("Language"), findsOneWidget);
      expect(find.text("Security"), findsOneWidget);
      expect(find.text("About"), findsOneWidget);
      expect(find.text("Logout"), findsOneWidget);
    });

    testWidgets("logout button calls provider logout", (tester) async {
      await storage.saveTokens(access: "a", refresh: "r");
      final authService = AuthService(dio: dio, storage: storage);
      interceptor.handler = (options) {
        return MockData({"message": "ok"}, 200);
      };

      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) {
            final p = AuthProvider(authService: authService, storage: storage);
            p.loadToken();
            return p;
          },
          child: const SettingsScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Logout"));
      await tester.pumpAndSettle();

      expect(await storage.getAccessToken(), isNull);
    });
  });
}
