import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mainapp/config/api_config.dart';
import 'package:mainapp/config/permissions.dart';
import 'package:mainapp/providers/auth_provider.dart';
import 'package:mainapp/providers/tweet_provider.dart';
import 'package:mainapp/models/tweet.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TweetProvider>().loadTweets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tweetProvider = context.watch<TweetProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final canCreate = auth.hasPermission(permTweetCreate);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Feed"),
        centerTitle: true,
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, "/create-tweet"),
              child: const Icon(Icons.add),
            )
          : null,
      body: tweetProvider.isLoading && tweetProvider.tweets.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : tweetProvider.error != null && tweetProvider.tweets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(tweetProvider.error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => tweetProvider.loadTweets(),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => tweetProvider.loadTweets(),
                  child: tweetProvider.tweets.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text("No tweets yet.")),
                          ],
                        )
                      : ListView.builder(
                          itemCount: tweetProvider.tweets.length,
                          itemBuilder: (context, index) {
                            final tweet = tweetProvider.tweets[index];
                            return _TweetCard(
                              tweet: tweet,
                              user: user,
                            );
                          },
                        ),
                ),
    );
  }
}

class _TweetCard extends StatelessWidget {
  final Tweet tweet;
  final Map<String, dynamic>? user;

  const _TweetCard({required this.tweet, this.user});

  @override
  Widget build(BuildContext context) {
    final tweetProvider = context.read<TweetProvider>();
    final auth = context.read<AuthProvider>();
    final roleColor = tweet.authorRole == "admin"
        ? Colors.red
        : tweet.authorRole == "staff"
            ? Colors.blue
            : tweet.authorRole == "moderator"
                ? Colors.orange
                : null;

    final isAuthor = tweet.isAuthor;
    final canEditAny = auth.hasPermission(permTweetEditAny);
    final canDeleteAny = auth.hasPermission(permTweetDeleteAny);
    final canEdit = isAuthor && auth.hasPermission(permTweetEditOwn);
    final canDelete = isAuthor && auth.hasPermission(permTweetDeleteOwn);
    final canShare = auth.hasPermission(permTweetShare);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  child: Text(
                    tweet.authorUsername[0].toUpperCase(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            tweet.authorUsername,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (tweet.authorRole != "user") ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: roleColor?.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tweet.authorRole.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: roleColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _formatDate(tweet.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                if (canDeleteAny || canEditAny || canDelete || canEdit)
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          Navigator.pushNamed(
                            context,
                            "/edit-tweet",
                            arguments: tweet,
                          );
                          break;
                        case 'delete':
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Delete Tweet"),
                              content: const Text(
                                  "Are you sure? This action cannot be undone."),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text("Delete"),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await tweetProvider.deleteTweet(tweet.uuid);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Tweet deleted."),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                          break;
                      }
                    },
                    itemBuilder: (context) {
                      final items = <PopupMenuEntry<String>>[];
                      if (canEditAny || canEdit) {
                        items.add(const PopupMenuItem(
                          value: 'edit',
                          child: Text("Edit"),
                        ));
                      }
                      if (canDeleteAny || canDelete) {
                        items.add(const PopupMenuItem(
                          value: 'delete',
                          child: Text("Delete", style: TextStyle(color: Colors.red)),
                        ));
                      }
                      return items;
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(tweet.content, style: const TextStyle(fontSize: 15)),
            if (tweet.imageUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  ApiConfig.mediaUrl(tweet.imageUrl!),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150,
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image)),
                    );
                  },
                ),
              ),
            ],
            if (canShare) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      final baseUri = Uri.base;
                      final origin = baseUri.scheme.startsWith('http')
                          ? "${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}"
                          : "http://localhost:8000";
                      final shareUrl = "$origin/#/tweets/${tweet.uuid}";
                      Clipboard.setData(ClipboardData(text: shareUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Link copied to clipboard."),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_outlined,
                            size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          "Share",
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
