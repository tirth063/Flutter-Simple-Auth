import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mainapp/providers/auth_provider.dart';
import 'package:mainapp/providers/tweet_provider.dart';
import 'package:mainapp/services/api_service.dart';
import 'package:mainapp/services/auth_service.dart';
import 'package:mainapp/services/tweet_service.dart';
import 'package:mainapp/services/secure_storage.dart';
import 'package:mainapp/app.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final storage = SecureStorage();
            final eventNotifier = ValueNotifier<AuthEvent?>(null);
            final dio = buildAuthDio(
              storage,
              onEvent: (event) => eventNotifier.value = event,
            );
            final authService = AuthService(dio: dio, storage: storage);
            return AuthProvider(
              authService: authService,
              storage: storage,
              eventNotifier: eventNotifier,
            )..loadToken();
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, TweetProvider>(
          create: (context) => TweetProvider(TweetService(context.read<AuthProvider>().dio)),
          update: (context, auth, previous) {
            if (previous != null) {
              previous.updateService(TweetService(auth.dio));
              return previous;
            }
            return TweetProvider(TweetService(auth.dio));
          },
        ),
      ],
      child: const App(),
    ),
  );
}
