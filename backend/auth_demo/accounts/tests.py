from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient
from .models import User, Tweet, Role, Permission


class AuthAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.register_url = "/api/auth/register/"
        self.login_url = "/api/auth/login/"
        self.logout_url = "/api/auth/logout/"
        self.me_url = "/api/auth/me/"
        self.protected_url = "/api/auth/protected/"
        self.refresh_url = "/api/auth/token/refresh/"

        self.user_role = Role.objects.get(name="user")
        self.admin_role = Role.objects.get(name="admin")

        self.valid_user = {
            "email": "test@example.com",
            "username": "testuser",
            "password": "testpass123!",
            "password_confirm": "testpass123!",
            "first_name": "Test",
            "last_name": "User",
        }

    def _register_user(self):
        return self.client.post(self.register_url, self.valid_user, format="json")

    def _login_user(self):
        self._register_user()
        return self.client.post(
            self.login_url,
            {"email": self.valid_user["email"], "password": self.valid_user["password"]},
            format="json",
        )

    def test_register_success(self):
        response = self._register_user()
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn("tokens", response.data)
        self.assertIn("access", response.data["tokens"])
        self.assertIn("refresh", response.data["tokens"])
        self.assertEqual(response.data["user"]["email"], self.valid_user["email"])
        self.assertTrue(User.objects.filter(email=self.valid_user["email"]).exists())

    def test_register_assigns_user_role(self):
        response = self._register_user()
        user = User.objects.get(email=self.valid_user["email"])
        self.assertEqual(user.role.name, "user")

    def test_register_returns_permissions(self):
        response = self._register_user()
        self.assertIn("permissions", response.data["user"])
        self.assertIsInstance(response.data["user"]["permissions"], list)

    def test_register_password_mismatch(self):
        data = self.valid_user.copy()
        data["password_confirm"] = "differentpass123"
        response = self.client.post(self.register_url, data, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("password", response.data)

    def test_register_duplicate_email(self):
        self._register_user()
        data = self.valid_user.copy()
        data["username"] = "testuser2"
        response = self.client.post(self.register_url, data, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_login_success(self):
        login_resp = self._login_user()
        self.assertEqual(login_resp.status_code, status.HTTP_200_OK)
        self.assertIn("tokens", login_resp.data)

    def test_login_invalid_credentials(self):
        response = self.client.post(
            self.login_url,
            {"email": "wrong@email.com", "password": "wrongpass"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_login_banned_user(self):
        self._register_user()
        user = User.objects.get(email=self.valid_user["email"])
        user.is_active = False
        user.save()
        response = self.client.post(
            self.login_url,
            {"email": self.valid_user["email"], "password": self.valid_user["password"]},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn("suspended", response.data["detail"].lower())

    def test_protected_without_auth(self):
        response = self.client.get(self.protected_url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_protected_with_auth(self):
        login_resp = self._login_user()
        access = login_resp.data["tokens"]["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
        response = self.client.get(self.protected_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_me_returns_role_and_permissions(self):
        login_resp = self._login_user()
        access = login_resp.data["tokens"]["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
        response = self.client.get(self.me_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("role", response.data)
        self.assertIn("permissions", response.data)
        self.assertEqual(response.data["role"], "user")

    def test_token_refresh(self):
        login_resp = self._login_user()
        refresh = login_resp.data["tokens"]["refresh"]
        response = self.client.post(self.refresh_url, {"refresh": refresh}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access", response.data)

    def test_logout(self):
        login_resp = self._login_user()
        refresh = login_resp.data["tokens"]["refresh"]
        access = login_resp.data["tokens"]["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
        response = self.client.post(self.logout_url, {"refresh": refresh}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)


class TweetAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.tweets_url = "/api/auth/tweets/"

        self.user_role = Role.objects.get(name="user")
        self.admin_role = Role.objects.get(name="admin")
        self.mod_role = Role.objects.get(name="moderator")

        self.user = User.objects.create_user(
            email="author@example.com", username="author", password="testpass123!"
        )
        self.user.role = self.user_role
        self.user.save()

        self.other_user = User.objects.create_user(
            email="other@example.com", username="other", password="testpass123!"
        )
        self.other_user.role = self.user_role
        self.other_user.save()

        self.admin_user = User.objects.create_superuser(
            email="admin@example.com", username="admin", password="testpass123!"
        )
        self.admin_user.role = self.admin_role
        self.admin_user.save()

        self.mod_user = User.objects.create_user(
            email="mod@example.com", username="mod", password="testpass123!"
        )
        self.mod_user.role = self.mod_role
        self.mod_user.save()

    def _auth(self, user):
        response = self.client.post(
            "/api/auth/login/",
            {"email": user.email, "password": "testpass123!"},
            format="json",
        )
        token = response.data["tokens"]["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_tweets_public_access(self):
        Tweet.objects.create(author=self.user, content="Public tweet")
        response = self.client.get(self.tweets_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)

    def test_create_tweet_requires_auth(self):
        response = self.client.post(self.tweets_url, {"content": "New tweet"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_create_tweet_authenticated(self):
        self._auth(self.user)
        response = self.client.post(self.tweets_url, {"content": "New tweet"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["content"], "New tweet")
        self.assertIn("uuid", response.data)
        self.assertIn("slug", response.data)

    def test_tweet_has_uuid_and_slug(self):
        self._auth(self.user)
        response = self.client.post(self.tweets_url, {"content": "Test tweet"}, format="json")
        self.assertIn("uuid", response.data)
        self.assertIn("slug", response.data)
        self.assertTrue(len(response.data["uuid"]) > 0)

    def test_get_tweet_by_uuid(self):
        self._auth(self.user)
        create_resp = self.client.post(self.tweets_url, {"content": "Share me"}, format="json")
        uuid = create_resp.data["uuid"]
        response = self.client.get(f"{self.tweets_url}{uuid}/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["content"], "Share me")

    def test_get_tweet_by_uuid_no_auth(self):
        self._auth(self.user)
        create_resp = self.client.post(self.tweets_url, {"content": "Public"}, format="json")
        uuid = create_resp.data["uuid"]
        self.client.credentials()
        response = self.client.get(f"{self.tweets_url}{uuid}/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_update_own_tweet(self):
        self._auth(self.user)
        create_resp = self.client.post(self.tweets_url, {"content": "Original"}, format="json")
        uuid = create_resp.data["uuid"]
        response = self.client.patch(
            f"{self.tweets_url}{uuid}/update/", {"content": "Updated"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["content"], "Updated")

    def test_update_other_user_tweet_forbidden(self):
        self._auth(self.user)
        create_resp = self.client.post(self.tweets_url, {"content": "Mine"}, format="json")
        uuid = create_resp.data["uuid"]
        self._auth(self.other_user)
        response = self.client.patch(
            f"{self.tweets_url}{uuid}/update/", {"content": "Hacked"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_delete_own_tweet(self):
        self._auth(self.user)
        create_resp = self.client.post(self.tweets_url, {"content": "Delete me"}, format="json")
        uuid = create_resp.data["uuid"]
        response = self.client.delete(f"{self.tweets_url}{uuid}/delete/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(Tweet.objects.filter(uuid=uuid).exists())

    def test_delete_other_user_tweet_forbidden(self):
        self._auth(self.user)
        create_resp = self.client.post(self.tweets_url, {"content": "Mine"}, format="json")
        uuid = create_resp.data["uuid"]
        self._auth(self.other_user)
        response = self.client.delete(f"{self.tweets_url}{uuid}/delete/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_moderator_can_delete_any_tweet(self):
        self._auth(self.user)
        create_resp = self.client.post(self.tweets_url, {"content": "User tweet"}, format="json")
        uuid = create_resp.data["uuid"]
        self._auth(self.mod_user)
        response = self.client.delete(f"{self.tweets_url}{uuid}/delete/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_moderator_can_edit_any_tweet(self):
        self._auth(self.user)
        create_resp = self.client.post(self.tweets_url, {"content": "Original"}, format="json")
        uuid = create_resp.data["uuid"]
        self._auth(self.mod_user)
        response = self.client.patch(
            f"{self.tweets_url}{uuid}/update/", {"content": "Mod edited"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["content"], "Mod edited")

    def test_create_tweet_content_too_long(self):
        self._auth(self.user)
        response = self.client.post(self.tweets_url, {"content": "x" * 281}, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_tweet_ordering_newest_first(self):
        Tweet.objects.create(author=self.user, content="First")
        Tweet.objects.create(author=self.user, content="Second")
        response = self.client.get(self.tweets_url)
        contents = [t["content"] for t in response.data]
        self.assertEqual(contents, ["Second", "First"])


class AdminAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()

        self.admin_role = Role.objects.get(name="admin")
        self.staff_role = Role.objects.get(name="staff")
        self.user_role = Role.objects.get(name="user")

        self.admin_user = User.objects.create_superuser(
            email="admin@example.com", username="admin", password="testpass123!"
        )
        self.admin_user.role = self.admin_role
        self.admin_user.save()

        self.staff_user = User.objects.create_user(
            email="staff@example.com", username="staff", password="testpass123!"
        )
        self.staff_user.role = self.staff_role
        self.staff_user.save()

        self.regular_user = User.objects.create_user(
            email="user@example.com", username="regular", password="testpass123!"
        )
        self.regular_user.role = self.user_role
        self.regular_user.save()

    def _auth(self, user):
        response = self.client.post(
            "/api/auth/login/",
            {"email": user.email, "password": "testpass123!"},
            format="json",
        )
        token = response.data["tokens"]["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_admin_user_list(self):
        self._auth(self.admin_user)
        response = self.client.get("/api/auth/admin/users/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 3)

    def test_admin_user_list_requires_user_view(self):
        self._auth(self.regular_user)
        response = self.client.get("/api/auth/admin/users/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_roles_list(self):
        self._auth(self.admin_user)
        response = self.client.get("/api/auth/admin/roles/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 4)

    def test_ban_user(self):
        self._auth(self.admin_user)
        response = self.client.post(f"/api/auth/admin/users/{self.regular_user.pk}/ban/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.regular_user.refresh_from_db()
        self.assertFalse(self.regular_user.is_active)

    def test_ban_user_requires_permission(self):
        user_role = Role.objects.get(name="user")
        limited_user = User.objects.create_user(
            email="limited@example.com", username="limited", password="testpass123!"
        )
        limited_user.role = user_role
        limited_user.save()
        self._auth(limited_user)
        response = self.client.post(f"/api/auth/admin/users/{self.regular_user.pk}/ban/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_unban_user(self):
        self.regular_user.is_active = False
        self.regular_user.save()
        self._auth(self.admin_user)
        response = self.client.post(f"/api/auth/admin/users/{self.regular_user.pk}/unban/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.regular_user.refresh_from_db()
        self.assertTrue(self.regular_user.is_active)

    def test_cannot_ban_self(self):
        self._auth(self.admin_user)
        response = self.client.post(f"/api/auth/admin/users/{self.admin_user.pk}/ban/")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_cannot_ban_superuser(self):
        self._auth(self.admin_user)
        response = self.client.post(f"/api/auth/admin/users/{self.admin_user.pk}/ban/")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_change_user_role(self):
        self._auth(self.admin_user)
        response = self.client.patch(
            f"/api/auth/admin/users/{self.regular_user.pk}/role/",
            {"role_id": self.staff_role.pk},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.regular_user.refresh_from_db()
        self.assertEqual(self.regular_user.role.name, "staff")

    def test_change_user_role_requires_permission(self):
        self._auth(self.staff_user)
        response = self.client.patch(
            f"/api/auth/admin/users/{self.regular_user.pk}/role/",
            {"role_id": self.admin_role.pk},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_cannot_change_own_role(self):
        self._auth(self.admin_user)
        response = self.client.patch(
            f"/api/auth/admin/users/{self.admin_user.pk}/role/",
            {"role_id": self.user_role.pk},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_update_role_permissions(self):
        perm = Permission.objects.get(code="TWEET_CREATE")
        self._auth(self.admin_user)
        response = self.client.patch(
            f"/api/auth/admin/roles/{self.user_role.pk}/",
            {"permission_ids": [perm.pk]},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_banned_user_cannot_login(self):
        self.regular_user.is_active = False
        self.regular_user.save()
        response = self.client.post(
            "/api/auth/login/",
            {"email": "user@example.com", "password": "testpass123!"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_unbanned_user_can_login(self):
        self.regular_user.is_active = False
        self.regular_user.save()
        self._auth(self.admin_user)
        self.client.post(f"/api/auth/admin/users/{self.regular_user.pk}/unban/")
        self.client.credentials()
        response = self.client.post(
            "/api/auth/login/",
            {"email": "user@example.com", "password": "testpass123!"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_admin_permission_list(self):
        self._auth(self.admin_user)
        response = self.client.get("/api/auth/admin/permissions/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreater(len(response.data), 0)
        self.assertIn("code", response.data[0])
