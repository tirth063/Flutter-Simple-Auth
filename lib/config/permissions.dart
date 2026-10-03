const String permTweetCreate = 'TWEET_CREATE';
const String permTweetView = 'TWEET_VIEW';
const String permTweetShare = 'TWEET_SHARE';
const String permTweetEditOwn = 'TWEET_EDIT_OWN';
const String permTweetEditAny = 'TWEET_EDIT_ANY';
const String permTweetDeleteOwn = 'TWEET_DELETE_OWN';
const String permTweetDeleteAny = 'TWEET_DELETE_ANY';
const String permUserView = 'USER_VIEW';
const String permUserBan = 'USER_BAN';
const String permUserUnban = 'USER_UNBAN';
const String permUserManageRoles = 'USER_MANAGE_ROLES';
const String permAdminPanel = 'ADMIN_PANEL';

bool hasPermission(Map<String, dynamic>? user, String code) {
  if (user == null) return false;
  final perms = user['permissions'] as List<dynamic>? ?? [];
  return perms.contains(code);
}
