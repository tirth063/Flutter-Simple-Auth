import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mainapp/services/tweet_service.dart';
import 'package:mainapp/services/secure_storage.dart';
import '../helpers/mocks.dart';

void main() {
  late Dio dio;
  late MockInterceptor interceptor;
  late TweetService tweetService;

  setUp(() {
    interceptor = MockInterceptor();
    dio = Dio(BaseOptions(baseUrl: "http://test.com"))
      ..interceptors.add(interceptor);
    tweetService = TweetService(dio);
  });

  group("TweetService - getTweets", () {
    test("should return list of tweets", () async {
      interceptor.handler = (options) {
        return MockData([
          {
            "id": 1,
            "uuid": "abc-123",
            "slug": "hello-world-abc123",
            "content": "Hello world",
            "image": null,
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z",
            "author_username": "alice",
            "author_email": "alice@test.com",
            "author_role": "user",
            "is_author": true,
          },
        ], 200);
      };

      final tweets = await tweetService.getTweets();
      expect(tweets.length, 1);
      expect(tweets[0].uuid, "abc-123");
      expect(tweets[0].slug, "hello-world-abc123");
      expect(tweets[0].content, "Hello world");
    });
  });

  group("TweetService - getTweetByUuid", () {
    test("should return tweet by uuid", () async {
      interceptor.handler = (options) {
        return MockData({
          "id": 1,
          "uuid": "abc-123",
          "slug": "test-tweet-abc123",
          "content": "Test tweet",
          "image": null,
          "created_at": "2026-01-01T00:00:00Z",
          "updated_at": "2026-01-01T00:00:00Z",
          "author_username": "alice",
          "author_email": "alice@test.com",
          "author_role": "user",
          "is_author": false,
        }, 200);
      };

      final tweet = await tweetService.getTweetByUuid("abc-123");
      expect(tweet.uuid, "abc-123");
      expect(tweet.content, "Test tweet");
    });

    test("should throw on not found", () async {
      interceptor.handler = (options) {
        throw DioException(
          requestOptions: RequestOptions(path: options.path),
          response: Response(
            requestOptions: RequestOptions(path: options.path),
            statusCode: 404,
            data: {"detail": "Tweet not found."},
          ),
        );
      };

      expect(
        () => tweetService.getTweetByUuid("nonexistent"),
        throwsA(isA<DioException>()),
      );
    });
  });

  group("TweetService - createTweet", () {
    test("should return created tweet", () async {
      interceptor.handler = (options) {
        return MockData({
          "id": 2,
          "uuid": "new-uuid-456",
          "slug": "new-tweet-new456",
          "content": "New tweet",
          "image": null,
          "created_at": "2026-01-01T00:00:00Z",
          "updated_at": "2026-01-01T00:00:00Z",
          "author_username": "alice",
          "author_email": "alice@test.com",
          "author_role": "user",
          "is_author": true,
        }, 201);
      };

      final tweet = await tweetService.createTweet(content: "New tweet");
      expect(tweet.content, "New tweet");
      expect(tweet.uuid, "new-uuid-456");
    });
  });

  group("TweetService - updateTweet", () {
    test("should return updated tweet", () async {
      interceptor.handler = (options) {
        return MockData({
          "id": 1,
          "uuid": "abc-123",
          "slug": "updated-tweet-abc123",
          "content": "Updated content",
          "image": null,
          "created_at": "2026-01-01T00:00:00Z",
          "updated_at": "2026-01-02T00:00:00Z",
          "author_username": "alice",
          "author_email": "alice@test.com",
          "author_role": "user",
          "is_author": true,
        }, 200);
      };

      final tweet = await tweetService.updateTweet(uuid: "abc-123", content: "Updated content");
      expect(tweet.content, "Updated content");
    });
  });

  group("TweetService - deleteTweet", () {
    test("should delete tweet by uuid", () async {
      bool deleteCalled = false;
      interceptor.handler = (options) {
        deleteCalled = true;
        return MockData({"message": "Tweet deleted successfully."}, 200);
      };

      await tweetService.deleteTweet("abc-123");
      expect(deleteCalled, true);
    });
  });
}
