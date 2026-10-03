import uuid as uuid_lib
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils.text import slugify


class Permission(models.Model):
    code = models.CharField(max_length=50, unique=True)
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True, default="")

    class Meta:
        ordering = ["code"]

    def __str__(self):
        return self.code


class Role(models.Model):
    name = models.CharField(max_length=30, unique=True)
    display_name = models.CharField(max_length=50)
    permissions = models.ManyToManyField(Permission, blank=True, related_name="roles")

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.display_name

    def has_permission(self, permission_code):
        return self.permissions.filter(code=permission_code).exists()


class User(AbstractUser):
    email = models.EmailField(unique=True)
    first_name = models.CharField(max_length=150, blank=True)
    last_name = models.CharField(max_length=150, blank=True)
    is_active = models.BooleanField(default=True)
    date_joined = models.DateTimeField(auto_now_add=True)
    role = models.ForeignKey(
        Role,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="users",
    )

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["username", "first_name", "last_name"]

    def __str__(self):
        return self.email

    @property
    def role_name(self):
        return self.role.name if self.role else "user"

    def has_permission(self, permission_code):
        if not self.is_authenticated:
            return False
        if self.role and self.role.has_permission(permission_code):
            return True
        return False


class Tweet(models.Model):
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name="tweets")
    content = models.TextField(max_length=280)
    image = models.ImageField(upload_to="tweets/", blank=True, null=True)
    uuid = models.UUIDField(default=uuid_lib.uuid4, unique=True, editable=False)
    slug = models.SlugField(max_length=300, unique=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def save(self, *args, **kwargs):
        if not self.slug:
            base_slug = slugify(self.content[:80]) or "tweet"
            self.slug = f"{base_slug}-{str(self.uuid)[:8]}"
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.author.username}: {self.content[:30]}"
