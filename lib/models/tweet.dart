class Tweet {
  final int id;
  final String uuid;
  final String slug;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String authorUsername;
  final String authorEmail;
  final String authorRole;
  final bool isAuthor;

  Tweet({
    required this.id,
    required this.uuid,
    required this.slug,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.authorUsername,
    required this.authorEmail,
    required this.authorRole,
    required this.isAuthor,
  });

  factory Tweet.fromJson(Map<String, dynamic> json) {
    return Tweet(
      id: json["id"] as int,
      uuid: json["uuid"] as String,
      slug: json["slug"] as String,
      content: json["content"] as String,
      imageUrl: json["image"] as String?,
      createdAt: DateTime.parse(json["created_at"] as String),
      updatedAt: DateTime.parse(json["updated_at"] as String),
      authorUsername: json["author_username"] as String,
      authorEmail: json["author_email"] as String,
      authorRole: json["author_role"] as String,
      isAuthor: json["is_author"] as bool,
    );
  }
}
