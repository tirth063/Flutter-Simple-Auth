from rest_framework import status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from .models import Tweet, Role, Permission
from .permissions import HasPermission, Perm
from .serializers import (
    RegisterSerializer,
    LoginSerializer,
    UserSerializer,
    AdminUserSerializer,
    AdminUserUpdateRoleSerializer,
    TweetSerializer,
    RoleSerializer,
    RoleUpdateSerializer,
    PermissionSerializer,
)

User = get_user_model()


class IsAdminOrAuthor(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return obj.author == request.user or (
            request.user and (request.user.is_staff or request.user.is_superuser)
        )


class RegisterView(APIView):
    permission_classes = []

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            user_role, _ = Role.objects.get_or_create(
                name="user", defaults={"display_name": "User"}
            )
            user.role = user_role
            user.save()
            refresh = RefreshToken.for_user(user)
            return Response(
                {
                    "message": "User registered successfully.",
                    "user": UserSerializer(user).data,
                    "tokens": {
                        "refresh": str(refresh),
                        "access": str(refresh.access_token),
                    },
                },
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LoginView(TokenObtainPairView):
    serializer_class = None

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data["email"]
        password = serializer.validated_data["password"]
        user = None
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            pass

        if user is not None and user.check_password(password):
            if not user.is_active:
                return Response(
                    {"detail": "Your account has been suspended. Contact support."},
                    status=status.HTTP_403_FORBIDDEN,
                )
            refresh = RefreshToken.for_user(user)
            return Response(
                {
                    "message": "Login successful.",
                    "user": UserSerializer(user).data,
                    "tokens": {
                        "refresh": str(refresh),
                        "access": str(refresh.access_token),
                    },
                }
            )
        return Response(
            {"detail": "Invalid email or password."},
            status=status.HTTP_401_UNAUTHORIZED,
        )


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            refresh_token = request.data.get("refresh")
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()
            return Response({"message": "Logout successful."}, status=status.HTTP_200_OK)
        except Exception:
            return Response(
                {"detail": "Invalid token."},
                status=status.HTTP_400_BAD_REQUEST,
            )


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user).data, status=status.HTTP_200_OK)


class ProtectedTestView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(
            {"message": f"Hello {request.user.email}, this is a protected endpoint."},
            status=status.HTTP_200_OK,
        )


class TweetListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == "GET":
            return [permissions.AllowAny()]
        return [IsAuthenticated()]

    def get(self, request):
        tweets = Tweet.objects.all().select_related("author", "author__role")
        serializer = TweetSerializer(tweets, many=True, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        if not request.user.has_permission(Perm.TWEET_CREATE):
            return Response(
                {"detail": "You do not have permission to create tweets.", "code": "permission_denied"},
                status=status.HTTP_403_FORBIDDEN,
            )
        serializer = TweetSerializer(data=request.data, context={"request": request})
        if serializer.is_valid():
            serializer.save(author=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class TweetDetailView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, uuid):
        try:
            tweet = Tweet.objects.select_related("author", "author__role").get(uuid=uuid)
        except Tweet.DoesNotExist:
            return Response({"detail": "Tweet not found."}, status=status.HTTP_404_NOT_FOUND)
        serializer = TweetSerializer(tweet, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)


class TweetUpdateView(APIView):
    permission_classes = [IsAuthenticated]

    def put(self, request, uuid):
        return self._update(request, uuid)

    def patch(self, request, uuid):
        return self._update(request, uuid)

    def _update(self, request, uuid):
        try:
            tweet = Tweet.objects.get(uuid=uuid)
        except Tweet.DoesNotExist:
            return Response({"detail": "Tweet not found."}, status=status.HTTP_404_NOT_FOUND)

        is_author = tweet.author == request.user
        can_edit = False
        if is_author and request.user.has_permission(Perm.TWEET_EDIT_OWN):
            can_edit = True
        if request.user.has_permission(Perm.TWEET_EDIT_ANY):
            can_edit = True

        if not can_edit:
            return Response(
                {"detail": "You do not have permission to edit this tweet.", "code": "permission_denied"},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = TweetSerializer(tweet, data=request.data, partial=True, context={"request": request})
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class TweetDeleteView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, uuid):
        try:
            tweet = Tweet.objects.get(uuid=uuid)
        except Tweet.DoesNotExist:
            return Response({"detail": "Tweet not found."}, status=status.HTTP_404_NOT_FOUND)

        is_author = tweet.author == request.user
        can_delete = False
        if is_author and request.user.has_permission(Perm.TWEET_DELETE_OWN):
            can_delete = True
        if request.user.has_permission(Perm.TWEET_DELETE_ANY):
            can_delete = True

        if not can_delete:
            return Response(
                {"detail": "You do not have permission to delete this tweet.", "code": "permission_denied"},
                status=status.HTTP_403_FORBIDDEN,
            )

        tweet.delete()
        return Response({"message": "Tweet deleted successfully."}, status=status.HTTP_200_OK)


class AdminRoleListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not request.user.has_permission(Perm.ADMIN_PANEL):
            return Response(
                {"detail": "You do not have permission to access the admin panel.", "code": "permission_denied"},
                status=status.HTTP_403_FORBIDDEN,
            )
        roles = Role.objects.prefetch_related("permissions").all()
        serializer = RoleSerializer(roles, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)


class AdminRoleUpdateView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        if not request.user.has_permission(Perm.USER_MANAGE_ROLES):
            return Response(
                {"detail": "You do not have permission to manage roles.", "code": "permission_denied"},
                status=status.HTTP_403_FORBIDDEN,
            )
        try:
            role = Role.objects.get(pk=pk)
        except Role.DoesNotExist:
            return Response({"detail": "Role not found."}, status=status.HTTP_404_NOT_FOUND)

        serializer = RoleUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        permissions = Permission.objects.filter(id__in=serializer.validated_data["permission_ids"])
        role.permissions.set(permissions)
        return Response(RoleSerializer(role).data, status=status.HTTP_200_OK)


class AdminPermissionListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not request.user.has_permission(Perm.USER_MANAGE_ROLES):
            return Response(
                {"detail": "You do not have permission to manage roles.", "code": "permission_denied"},
                status=status.HTTP_403_FORBIDDEN,
            )
        permissions = Permission.objects.all().order_by("code")
        serializer = PermissionSerializer(permissions, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)


class AdminUserListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not request.user.has_permission(Perm.USER_VIEW):
            return Response(
                {"detail": "You do not have permission to view users.", "code": "permission_denied"},
                status=status.HTTP_403_FORBIDDEN,
            )
        users = User.objects.select_related("role").all().order_by("-date_joined")
        serializer = AdminUserSerializer(users, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)


class AdminUserBanView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        if not request.user.has_permission(Perm.USER_BAN):
            return Response(
                {"detail": "You do not have permission to ban users.", "code": "permission_denied"},
                status=status.HTTP_403_FORBIDDEN,
            )
        try:
            user = User.objects.get(pk=pk)
        except User.DoesNotExist:
            return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)

        if user == request.user:
            return Response(
                {"detail": "You cannot ban yourself."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if user.is_superuser:
            return Response(
                {"detail": "Cannot ban a superuser."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.is_active = False
        user.save()
        return Response(
            {"message": f"User {user.email} has been banned.", "is_active": False},
            status=status.HTTP_200_OK,
        )


class AdminUserUnbanView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        if not request.user.has_permission(Perm.USER_UNBAN):
            return Response(
                {"detail": "You do not have permission to unban users.", "code": "permission_denied"},
                status=status.HTTP_403_FORBIDDEN,
            )
        try:
            user = User.objects.get(pk=pk)
        except User.DoesNotExist:
            return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)

        user.is_active = True
        user.save()
        return Response(
            {"message": f"User {user.email} has been unbanned.", "is_active": True},
            status=status.HTTP_200_OK,
        )


class AdminUserUpdateRoleView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        if not request.user.has_permission(Perm.USER_MANAGE_ROLES):
            return Response(
                {"detail": "You do not have permission to manage roles.", "code": "permission_denied"},
                status=status.HTTP_403_FORBIDDEN,
            )
        try:
            user = User.objects.get(pk=pk)
        except User.DoesNotExist:
            return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)

        if user == request.user:
            return Response(
                {"detail": "You cannot change your own role."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if user.is_superuser:
            return Response(
                {"detail": "Cannot change the role of a superuser."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = AdminUserUpdateRoleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            role = Role.objects.get(pk=serializer.validated_data["role_id"])
        except Role.DoesNotExist:
            return Response({"detail": "Role not found."}, status=status.HTTP_404_NOT_FOUND)

        user.role = role
        user.save()
        return Response(
            AdminUserSerializer(user).data,
            status=status.HTTP_200_OK,
        )
