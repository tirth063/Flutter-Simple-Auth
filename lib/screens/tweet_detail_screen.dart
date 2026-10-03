import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mainapp/config/api_config.dart';
import 'package:mainapp/providers/tweet_provider.dart';
import 'package:mainapp/models/tweet.dart';

class TweetDetailScreen extends StatefulWidget {
  final String uuid;

  const TweetDetailScreen({super.key, required this.uuid});

  @override
  State<TweetDetailScreen> createState() => _TweetDetailScreenState();
}

class _TweetDetailScreenState extends State<TweetDetailScreen> {
  Tweet? _tweet;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTweet());
  }

  Future<void> _loadTweet() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final tweetProvider = context.read<TweetProvider>();
      final tweet = await tweetProvider.getTweetByUuid(widget.uuid);
      if (tweet != null) {
        setState(() {
          _tweet = tweet;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Tweet not found.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Failed to load tweet.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tweet"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTweet,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : _buildTweet(_tweet!),
    );
  }

  Widget _buildTweet(Tweet tweet) {
    final roleColor = tweet.authorRole == "admin"
        ? Colors.red
        : tweet.authorRole == "staff"
            ? Colors.blue
            : tweet.authorRole == "moderator"
                ? Colors.orange
                : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                child: Text(
                  tweet.authorUsername[0].toUpperCase(),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
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
                            fontSize: 16,
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
                      tweet.authorEmail,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tweet.content,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          if (tweet.imageUrl != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                ApiConfig.mediaUrl(tweet.imageUrl!),
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.broken_image)),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            _formatDateTime(tweet.createdAt),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          if (tweet.updatedAt.isAfter(
            tweet.createdAt.add(const Duration(seconds: 5)),
          )) ...[
            const SizedBox(height: 4),
            Text(
              "Edited ${_formatDateTime(tweet.updatedAt)}",
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return "${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}
