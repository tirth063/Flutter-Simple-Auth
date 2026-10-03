import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:mainapp/providers/auth_provider.dart';
import 'package:mainapp/screens/login_screen.dart';
import 'package:mainapp/services/auth_service.dart';
import 'package:mainapp/services/secure_storage.dart';
import '../helpers/mocks.dart';

Widget createLoginScreen(Dio dio, SecureStorage storage) {
  final authService = AuthService(dio: dio, storage: storage);
  final authProvider = AuthProvider(authService: authService);
  return ChangeNotifierProvider<AuthProvider>.value(
    value: authProvider,
    child: const MaterialApp(home: LoginScreen()),
  );
}

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

  group("LoginScreen - UI", () {
    testWidgets("should display login form elements", (tester) async {
      await tester.pumpWidget(createLoginScreen(dio, storage));
      await tester.pumpAndSettle();

      expect(find.text("Welcome Back"), findsOneWidget);
      expect(find.text("Sign in to continue"), findsOneWidget);
      expect(find.text("Sign In"), findsOneWidget);
      expect(find.text("Don't have an account? "), findsOneWidget);
      expect(find.text("Register"), findsOneWidget);
    });

    testWidgets("should show validation errors for empty fields", (tester) async {
      await tester.pumpWidget(createLoginScreen(dio, storage));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Sign In"));
      await tester.pumpAndSettle();

      expect(find.text("Enter your email"), findsOneWidget);
      expect(find.text("Enter your password"), findsOneWidget);
    });

    testWidgets("should show error SnackBar on failed login", (tester) async {
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

      await tester.pumpWidget(createLoginScreen(dio, storage));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, "test@test.com");
      await tester.enterText(find.byType(TextFormField).last, "wrongpass");
      await tester.tap(find.text("Sign In"));
      await tester.pumpAndSettle();

      expect(find.text("Invalid email or password."), findsOneWidget);
    });

    testWidgets("should navigate to Register screen", (tester) async {
      await tester.pumpWidget(createLoginScreen(dio, storage));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Register"));
      await tester.pumpAndSettle();

      expect(find.text("Create Account"), findsOneWidget);
    });
  });
}
