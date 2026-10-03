import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:mainapp/providers/auth_provider.dart';
import 'package:mainapp/screens/register_screen.dart';
import 'package:mainapp/services/auth_service.dart';
import 'package:mainapp/services/secure_storage.dart';
import '../helpers/mocks.dart';

Widget createRegisterScreen(Dio dio, SecureStorage storage) {
  final authService = AuthService(dio: dio, storage: storage);
  final authProvider = AuthProvider(authService: authService, storage: storage);
  return ChangeNotifierProvider<AuthProvider>.value(
    value: authProvider,
    child: const MaterialApp(home: RegisterScreen()),
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

  group("RegisterScreen - UI", () {
    testWidgets("should display form elements", (tester) async {
      await tester.pumpWidget(createRegisterScreen(dio, storage));
      await tester.pumpAndSettle();

      expect(find.text("Get Started"), findsOneWidget);
      expect(find.text("Create your account"), findsOneWidget);
      expect(find.text("Sign Up"), findsOneWidget);
      expect(find.text("Already have an account? "), findsOneWidget);
      expect(find.text("Sign In"), findsOneWidget);
    });

    testWidgets("should show validation errors for empty fields",
        (tester) async {
      await tester.pumpWidget(createRegisterScreen(dio, storage));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Sign Up"));
      await tester.pumpAndSettle();

      expect(find.text("Username is required"), findsOneWidget);
      expect(find.text("Email is required"), findsOneWidget);
      expect(find.text("Password is required"), findsOneWidget);
      expect(find.text("Please confirm your password"), findsOneWidget);
    });

    testWidgets("should show error SnackBar on failed registration",
        (tester) async {
      interceptor.handler = (options) {
        throw DioException(
          requestOptions: RequestOptions(path: options.path),
          response: Response(
            requestOptions: RequestOptions(path: options.path),
            statusCode: 400,
            data: {"email": ["Email already exists."]},
          ),
        );
      };

      await tester.pumpWidget(createRegisterScreen(dio, storage));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), "newuser");
      await tester.enterText(find.byType(TextFormField).at(1), "dup@test.com");
      await tester.enterText(find.byType(TextFormField).at(2), "pass1234");
      await tester.enterText(find.byType(TextFormField).at(3), "pass1234");
      await tester.tap(find.text("Sign Up"));
      await tester.pumpAndSettle();

      expect(find.text("Email already exists."), findsOneWidget);
    });
  });
}
