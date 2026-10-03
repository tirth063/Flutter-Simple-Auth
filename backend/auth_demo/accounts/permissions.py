from rest_framework.permissions import BasePermission


class Perm:
    TWEET_CREATE = "TWEET_CREATE"
    TWEET_VIEW = "TWEET_VIEW"
    TWEET_SHARE = "TWEET_SHARE"
    TWEET_EDIT_OWN = "TWEET_EDIT_OWN"
    TWEET_EDIT_ANY = "TWEET_EDIT_ANY"
    TWEET_DELETE_OWN = "TWEET_DELETE_OWN"
    TWEET_DELETE_ANY = "TWEET_DELETE_ANY"
    USER_VIEW = "USER_VIEW"
    USER_BAN = "USER_BAN"
    USER_UNBAN = "USER_UNBAN"
    USER_MANAGE_ROLES = "USER_MANAGE_ROLES"
    ADMIN_PANEL = "ADMIN_PANEL"

    ALL = [
        TWEET_CREATE, TWEET_VIEW, TWEET_SHARE,
        TWEET_EDIT_OWN, TWEET_EDIT_ANY,
        TWEET_DELETE_OWN, TWEET_DELETE_ANY,
        USER_VIEW, USER_BAN, USER_UNBAN,
        USER_MANAGE_ROLES, ADMIN_PANEL,
    ]


ROLE_DEFAULTS = {
    "user": [
        Perm.TWEET_CREATE, Perm.TWEET_VIEW, Perm.TWEET_SHARE,
        Perm.TWEET_EDIT_OWN, Perm.TWEET_DELETE_OWN,
    ],
    "moderator": [
        Perm.TWEET_VIEW, Perm.TWEET_SHARE,
        Perm.TWEET_EDIT_OWN, Perm.TWEET_EDIT_ANY,
        Perm.TWEET_DELETE_OWN, Perm.TWEET_DELETE_ANY,
    ],
    "staff": [
        Perm.TWEET_VIEW, Perm.TWEET_SHARE,
        Perm.TWEET_EDIT_OWN, Perm.TWEET_DELETE_OWN,
        Perm.USER_VIEW, Perm.USER_BAN, Perm.USER_UNBAN,
    ],
    "admin": Perm.ALL,
}


class HasPermission(BasePermission):
    def __init__(self, permission_code):
        self.permission_code = permission_code

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        if user.role and user.role.has_permission(self.permission_code):
            return True
        return False

    def __call__(self):
        return self
