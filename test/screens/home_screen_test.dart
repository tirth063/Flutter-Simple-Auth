import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mainapp/providers/auth_provider.dart';
import 'package:mainapp/screens/home_screen.dart';
import 'package:mainapp/services/api_service.dart';
import 'package:mainapp/services/auth_service.dart';
import 'package:mainapp/services/secure_storage.dart';

import '../helpers/mocks.dart';

void main() {
  group("HomeScreen", () {
    testWidgets("displays fallback when user is null", (tester) async {
      final storage = InMemorySecureStorage();
      final eventNotifier = ValueNotifier<AuthEvent?>(null);
      final dio = buildAuthDio(storage, onEvent: (e) => eventNotifier.value = e);
      final authService = AuthService(dio: dio, storage: storage);
      final provider = AuthProvider(
        authService: authService,
        storage: storage,
        eventNotifier: eventNotifier,
      );

      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: const HomeScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text("Welcome, User"), findsOneWidget);
    });
  });
}
