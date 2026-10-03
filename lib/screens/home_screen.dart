import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mainapp/providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                "Welcome, ${user?['email'] ?? 'User'}",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                "This is a protected home screen.",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text("Email"),
                  subtitle: Text(user?['email'] ?? "N/A"),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text("Username"),
                  subtitle: Text(user?['username'] ?? "N/A"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}