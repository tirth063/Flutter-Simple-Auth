import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mainapp/providers/auth_provider.dart';
import 'package:mainapp/screens/splash_screen.dart';
import 'package:mainapp/screens/login_screen.dart';
import 'package:mainapp/screens/feed_screen.dart';
import 'package:mainapp/screens/create_tweet_screen.dart';
import 'package:mainapp/screens/profile_screen.dart';
import 'package:mainapp/screens/admin_screen.dart';
import 'package:mainapp/screens/auth_status_screen.dart';
import 'package:mainapp/screens/tweet_detail_screen.dart';
import 'package:mainapp/models/tweet.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    Widget home;
    if (auth.status == AuthStatus.initial) {
      home = const SplashScreen();
    } else if (auth.status == AuthStatus.unauthenticated) {
      home = const LoginScreen();
    } else {
      home = const _MainNavScreen();
    }

    return MaterialApp(
      title: "Auth Demo",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6750A4),
        brightness: Brightness.light,
      ),
      home: home,
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        if (name.startsWith('/tweets/')) {
          final uri = Uri.parse(name);
          final segments = uri.pathSegments;
          if (segments.length >= 2 && segments[0] == 'tweets') {
            return MaterialPageRoute(
              builder: (_) => TweetDetailScreen(uuid: segments[1]),
            );
          }
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text("Invalid tweet link.")),
            ),
          );
        }

        switch (name) {
          case '/create-tweet':
            return MaterialPageRoute(
              builder: (_) => const CreateTweetScreen(),
            );
          case '/edit-tweet':
            final tweet = settings.arguments as Tweet;
            return MaterialPageRoute(
              builder: (_) => CreateTweetScreen(editTweet: tweet),
            );
          case '/admin':
            return MaterialPageRoute(
              builder: (_) => const AdminScreen(),
            );
          default:
            return null;
        }
      },
    );
  }
}

class _MainNavScreen extends StatefulWidget {
  const _MainNavScreen();

  @override
  State<_MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<_MainNavScreen> {
  int _currentIndex = 0;

  static const _screens = [
    FeedScreen(),
    ProfileScreen(),
    AuthStatusScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: "Feed",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: "Profile",
          ),
          NavigationDestination(
            icon: Icon(Icons.security_outlined),
            selectedIcon: Icon(Icons.security),
            label: "Auth",
          ),
        ],
      ),
    );
  }
}
