import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mainapp/config/api_config.dart';
import 'package:mainapp/models/tweet.dart';

class TweetService {
  final Dio _dio;

  TweetService(this._dio);

  Future<List<Tweet>> getTweets() async {
    final response = await _dio.get(ApiConfig.tweetsUrl);
    final data = response.data as List;
    return data.map((json) => Tweet.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Tweet> getTweetByUuid(String uuid) async {
    final response = await _dio.get(ApiConfig.tweetByUuidUrl(uuid));
    return Tweet.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Tweet> createTweet({
    required String content,
    XFile? imageFile,
  }) async {
    final formData = FormData.fromMap({
      "content": content,
    });

    if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      formData.files.add(MapEntry(
        "image",
        MultipartFile.fromBytes(
          bytes,
          filename: imageFile.name,
        ),
      ));
    }

    final response = await _dio.post(
      ApiConfig.tweetsUrl,
      data: formData,
      options: Options(
        headers: {"Content-Type": "multipart/form-data"},
      ),
    );
    return Tweet.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Tweet> updateTweet({
    required String uuid,
    required String content,
  }) async {
    final response = await _dio.patch(
      ApiConfig.tweetUpdateUrl(uuid),
      data: {"content": content},
    );
    return Tweet.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteTweet(String uuid) async {
    await _dio.delete(ApiConfig.tweetDeleteUrl(uuid));
  }
}
