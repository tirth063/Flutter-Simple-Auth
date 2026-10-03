import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mainapp/providers/auth_provider.dart';
import 'package:mainapp/providers/tweet_provider.dart';
import 'package:mainapp/config/permissions.dart';
import 'package:mainapp/models/tweet.dart';
import 'package:mainapp/config/api_config.dart';
import 'package:mainapp/screens/settings_screen.dart';
import 'package:mainapp/screens/admin_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final tweets = context.watch<TweetProvider>().tweets;
    final myTweets = user != null
        ? tweets.where((t) => t.authorUsername == user["username"]).toList()
        : <Tweet>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    (user["username"] ?? "?")[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 32,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user["username"] ?? "N/A",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  user["email"] ?? "N/A",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _roleColor(user["role"]).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (user["role"] ?? "user").toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _roleColor(user["role"]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (auth.hasPermission(permAdminPanel))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.admin_panel_settings),
                        label: const Text("Admin Panel"),
                      ),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _infoRow(Icons.email_outlined, "Email", user["email"]),
                        const Divider(),
                        _infoRow(Icons.person_outline, "Username", user["username"]),
                        const Divider(),
                        _infoRow(Icons.security_outlined, "Role",
                            user["role"] ?? "user"),
                        const Divider(),
                        _infoRow(Icons.calendar_today_outlined, "Joined",
                            user["date_joined"] != null
                                ? (user["date_joined"] as String).substring(0, 10)
                                : "N/A"),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "My Tweets (${myTweets.length})",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (myTweets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        "You haven't posted anything yet.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...myTweets.map(
                    (tweet) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          tweet.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _formatDate(tweet.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        trailing: tweet.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  ApiConfig.mediaUrl(tweet.imageUrl!),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image, size: 20),
                                    );
                                  },
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'staff':
        return Colors.blue;
      case 'moderator':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _infoRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Flexible(
            child: Text(
              value?.toString() ?? "N/A",
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${date.month}/${date.day}/${date.year}";
  }
}
