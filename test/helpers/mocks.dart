import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:mainapp/services/secure_storage.dart';
import 'package:mainapp/providers/tweet_provider.dart';
import 'package:mainapp/services/tweet_service.dart';

class MockInterceptor extends Interceptor {
  MockData Function(RequestOptions)? handler;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (this.handler != null) {
      try {
        final mock = this.handler!(options);
        handler.resolve(
          Response(
            requestOptions: options,
            data: mock.data,
            statusCode: mock.statusCode,
          ),
        );
      } on DioException catch (e) {
        handler.reject(e);
      }
    } else {
      handler.next(options);
    }
  }
}

class MockAdapter implements HttpClientAdapter {
  MockData Function(RequestOptions)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (handler == null) {
      throw UnimplementedError("No mock handler set");
    }
    final result = handler!(options);
    return ResponseBody.fromString(
      jsonEncode(result.data),
      result.statusCode,
      headers: {"content-type": ["application/json"]},
    );
  }

  @override
  void close({bool force = false}) {}
}

class MockData {
  final dynamic data;
  final int statusCode;
  MockData(this.data, this.statusCode);
}

class InMemorySecureStorage extends SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> saveTokens({required String access, required String refresh}) async {
    _store["access_token"] = access;
    _store["refresh_token"] = refresh;
  }

  @override
  Future<void> saveAccessToken(String access) async {
    _store["access_token"] = access;
  }

  @override
  Future<String?> getAccessToken() async => _store["access_token"];

  @override
  Future<String?> getRefreshToken() async => _store["refresh_token"];

  @override
  Future<void> clearAll() async => _store.clear();
}

TweetProvider mockTweetProvider() {
  final dio = Dio(BaseOptions(baseUrl: "http://test.com"));
  final adapter = MockAdapter();
  adapter.handler = (options) => MockData([], 200);
  dio.httpClientAdapter = adapter;
  return TweetProvider(TweetService(dio));
}
