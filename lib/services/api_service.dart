import 'dart:async';
import 'package:dio/dio.dart';
import 'package:mainapp/config/api_config.dart';
import 'package:mainapp/services/secure_storage.dart';

Dio buildAuthDio(SecureStorage storage, {void Function(AuthEvent)? onEvent}) {
  var isRefreshing = false;
  Completer<String?>? refreshCompleter;

  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {"Content-Type": "application/json"},
    ),
  );

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      if (options.path.contains("/auth/token/refresh/")) {
        handler.next(options);
        return;
      }
      final token = await storage.getAccessToken();
      if (token != null) {
        options.headers["Authorization"] = "Bearer $token";
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode != 401) {
        handler.next(error);
        return;
      }

      if (error.requestOptions.path.contains("/auth/token/refresh/")) {
        isRefreshing = false;
        refreshCompleter = null;
        await storage.clearAll();
        onEvent?.call(AuthEvent.tokenCleared);
        handler.next(error);
        return;
      }

      if (isRefreshing) {
        try {
          final newAccess = await refreshCompleter?.future;
          if (newAccess != null) {
            error.requestOptions.headers["Authorization"] = "Bearer $newAccess";
            final retryResponse = await dio.fetch<dynamic>(error.requestOptions);
            handler.resolve(retryResponse);
            return;
          }
        } catch (_) {}
        handler.next(error);
        return;
      }

      isRefreshing = true;
      refreshCompleter = Completer<String?>();

      try {
        final refreshToken = await storage.getRefreshToken();
        if (refreshToken == null) {
          isRefreshing = false;
          refreshCompleter?.complete(null);
          refreshCompleter = null;
          onEvent?.call(AuthEvent.refreshFailed);
          handler.next(error);
          return;
        }

        final response = await dio.post(
          ApiConfig.refreshUrl,
          data: {"refresh": refreshToken},
          options: Options(headers: {"Authorization": null}),
        );
        final newAccess = response.data["access"] as String;
        final newRefresh = response.data["refresh"] as String?;

        if (newRefresh != null) {
          await storage.saveTokens(access: newAccess, refresh: newRefresh);
        } else {
          await storage.saveAccessToken(newAccess);
        }

        onEvent?.call(AuthEvent.tokenRefreshed);
        refreshCompleter?.complete(newAccess);

        error.requestOptions.headers["Authorization"] = "Bearer $newAccess";
        final retryResponse = await dio.fetch<dynamic>(error.requestOptions);
        handler.resolve(retryResponse);
      } on DioException catch (e) {
        onEvent?.call(AuthEvent.refreshFailed);
        if (e.response?.statusCode == 401) {
          await storage.clearAll();
          onEvent?.call(AuthEvent.tokenCleared);
        }
        refreshCompleter?.complete(null);
        handler.next(error);
      } catch (_) {
        refreshCompleter?.complete(null);
        handler.next(error);
      } finally {
        isRefreshing = false;
        refreshCompleter = null;
      }
    },
  ));

  return dio;
}
