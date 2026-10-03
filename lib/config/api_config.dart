import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      final baseUri = Uri.base;
      if (baseUri.scheme.startsWith('http')) {
        return "${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}";
      }
    }
    return "http://localhost:8000";
  }
  static const String authPrefix = "/api/auth";

  static String get registerUrl => "$baseUrl$authPrefix/register/";
  static String get loginUrl => "$baseUrl$authPrefix/login/";
  static String get logoutUrl => "$baseUrl$authPrefix/logout/";
  static String get meUrl => "$baseUrl$authPrefix/me/";
  static String get protectedUrl => "$baseUrl$authPrefix/protected/";
  static String get refreshUrl => "$baseUrl$authPrefix/token/refresh/";

  static String get tweetsUrl => "$baseUrl$authPrefix/tweets/";
  static String tweetByUuidUrl(String uuid) => "$baseUrl$authPrefix/tweets/$uuid/";
  static String tweetUpdateUrl(String uuid) => "$baseUrl$authPrefix/tweets/$uuid/update/";
  static String tweetDeleteUrl(String uuid) => "$baseUrl$authPrefix/tweets/$uuid/delete/";

  static String get adminRolesUrl => "$baseUrl$authPrefix/admin/roles/";
  static String adminRoleUpdateUrl(int id) => "$baseUrl$authPrefix/admin/roles/$id/";
  static String get adminPermissionsUrl => "$baseUrl$authPrefix/admin/permissions/";
  static String get adminUsersUrl => "$baseUrl$authPrefix/admin/users/";
  static String adminUserBanUrl(int id) => "$baseUrl$authPrefix/admin/users/$id/ban/";
  static String adminUserUnbanUrl(int id) => "$baseUrl$authPrefix/admin/users/$id/unban/";
  static String adminUserUpdateRoleUrl(int id) => "$baseUrl$authPrefix/admin/users/$id/role/";

  static String mediaUrl(String path) => "$baseUrl/media/$path";
}
