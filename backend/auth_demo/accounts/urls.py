from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    RegisterView,
    LoginView,
    LogoutView,
    MeView,
    ProtectedTestView,
    TweetListCreateView,
    TweetDetailView,
    TweetUpdateView,
    TweetDeleteView,
    AdminRoleListView,
    AdminRoleUpdateView,
    AdminUserListView,
    AdminUserBanView,
    AdminUserUnbanView,
    AdminUserUpdateRoleView,
    AdminPermissionListView,
)

urlpatterns = [
    path("register/", RegisterView.as_view(), name="register"),
    path("login/", LoginView.as_view(), name="login"),
    path("logout/", LogoutView.as_view(), name="logout"),
    path("me/", MeView.as_view(), name="me"),
    path("protected/", ProtectedTestView.as_view(), name="protected-test"),
    path("token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),

    path("tweets/", TweetListCreateView.as_view(), name="tweet-list-create"),
    path("tweets/<uuid:uuid>/", TweetDetailView.as_view(), name="tweet-detail"),
    path("tweets/<uuid:uuid>/update/", TweetUpdateView.as_view(), name="tweet-update"),
    path("tweets/<uuid:uuid>/delete/", TweetDeleteView.as_view(), name="tweet-delete"),

    path("admin/roles/", AdminRoleListView.as_view(), name="admin-role-list"),
    path("admin/roles/<int:pk>/", AdminRoleUpdateView.as_view(), name="admin-role-update"),
    path("admin/permissions/", AdminPermissionListView.as_view(), name="admin-permission-list"),
    path("admin/users/", AdminUserListView.as_view(), name="admin-user-list"),
    path("admin/users/<int:pk>/ban/", AdminUserBanView.as_view(), name="admin-user-ban"),
    path("admin/users/<int:pk>/unban/", AdminUserUnbanView.as_view(), name="admin-user-unban"),
    path("admin/users/<int:pk>/role/", AdminUserUpdateRoleView.as_view(), name="admin-user-update-role"),
]
