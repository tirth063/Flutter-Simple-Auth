from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from .models import Tweet, Role, Permission

User = get_user_model()


class PermissionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Permission
        fields = ["id", "code", "name", "description"]


class RoleSerializer(serializers.ModelSerializer):
    permissions = PermissionSerializer(many=True, read_only=True)
    user_count = serializers.SerializerMethodField()

    class Meta:
        model = Role
        fields = ["id", "name", "display_name", "permissions", "user_count"]
        read_only_fields = ["id"]

    def get_user_count(self, obj):
        return obj.users.count()


class RoleUpdateSerializer(serializers.Serializer):
    permission_ids = serializers.ListField(
        child=serializers.IntegerField(),
        required=True,
    )


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ["email", "username", "password", "password_confirm", "first_name", "last_name"]

    def validate(self, attrs):
        if attrs["password"] != attrs["password_confirm"]:
            raise serializers.ValidationError({"password": "Passwords do not match."})
        return attrs

    def create(self, validated_data):
        validated_data.pop("password_confirm")
        user = User.objects.create_user(**validated_data)
        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)


class UserSerializer(serializers.ModelSerializer):
    role = serializers.SerializerMethodField()
    permissions = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id", "email", "username", "first_name", "last_name",
            "date_joined", "role", "is_staff", "is_superuser", "is_active",
            "permissions",
        ]
        read_only_fields = [
            "id", "date_joined", "role", "is_staff", "is_superuser",
            "is_active", "permissions",
        ]

    def get_role(self, obj):
        if obj.role:
            return obj.role.name
        return "user"

    def get_permissions(self, obj):
        if obj.role:
            return list(obj.role.permissions.values_list("code", flat=True))
        return []


class AdminUserSerializer(serializers.ModelSerializer):
    role = serializers.SerializerMethodField()
    role_id = serializers.PrimaryKeyRelatedField(
        queryset=Role.objects.all(),
        source="role",
        write_only=True,
        required=False,
    )
    role_name = serializers.CharField(source="role.display_name", read_only=True)
    permissions = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id", "email", "username", "first_name", "last_name",
            "date_joined", "role", "role_id", "role_name",
            "is_staff", "is_superuser", "is_active", "permissions",
        ]
        read_only_fields = [
            "id", "date_joined", "role_name", "is_staff", "is_superuser",
            "permissions",
        ]

    def get_role(self, obj):
        if obj.role:
            return obj.role.name
        return "user"

    def get_permissions(self, obj):
        if obj.role:
            return list(obj.role.permissions.values_list("code", flat=True))
        return []


class AdminUserUpdateRoleSerializer(serializers.Serializer):
    role_id = serializers.IntegerField()


class TweetSerializer(serializers.ModelSerializer):
    author_username = serializers.CharField(source="author.username", read_only=True)
    author_email = serializers.CharField(source="author.email", read_only=True)
    author_role = serializers.SerializerMethodField()
    is_author = serializers.SerializerMethodField()

    class Meta:
        model = Tweet
        fields = [
            "id", "uuid", "slug", "content", "image", "created_at", "updated_at",
            "author_username", "author_email", "author_role", "is_author",
        ]
        read_only_fields = [
            "id", "uuid", "slug", "created_at", "updated_at",
            "author_username", "author_email", "author_role", "is_author",
        ]

    def get_author_role(self, obj):
        return obj.author.role_name

    def get_is_author(self, obj):
        request = self.context.get("request")
        if request and request.user and not request.user.is_anonymous:
            return obj.author == request.user
        return False
