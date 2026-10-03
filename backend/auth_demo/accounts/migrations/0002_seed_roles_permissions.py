from django.db import migrations


PERMISSIONS = [
    ("TWEET_CREATE", "Create tweets", "Can create new tweets"),
    ("TWEET_VIEW", "View tweets", "Can view tweets"),
    ("TWEET_SHARE", "Share tweets", "Can share tweets via links"),
    ("TWEET_EDIT_OWN", "Edit own tweets", "Can edit own tweets"),
    ("TWEET_EDIT_ANY", "Edit any tweet", "Can edit any user's tweets"),
    ("TWEET_DELETE_OWN", "Delete own tweets", "Can delete own tweets"),
    ("TWEET_DELETE_ANY", "Delete any tweet", "Can delete any user's tweets"),
    ("USER_VIEW", "View users", "Can view user list"),
    ("USER_BAN", "Ban users", "Can ban (deactivate) users"),
    ("USER_UNBAN", "Unban users", "Can unban (reactivate) users"),
    ("USER_MANAGE_ROLES", "Manage roles", "Can assign roles and permissions to users"),
    ("ADMIN_PANEL", "Admin panel", "Can access the admin panel"),
]

ROLES = {
    "user": {
        "display_name": "User",
        "permissions": [
            "TWEET_CREATE", "TWEET_VIEW", "TWEET_SHARE",
            "TWEET_EDIT_OWN", "TWEET_DELETE_OWN",
        ],
    },
    "moderator": {
        "display_name": "Moderator",
        "permissions": [
            "TWEET_VIEW", "TWEET_SHARE",
            "TWEET_EDIT_OWN", "TWEET_EDIT_ANY",
            "TWEET_DELETE_OWN", "TWEET_DELETE_ANY",
            "ADMIN_PANEL",
        ],
    },
    "staff": {
        "display_name": "Staff",
        "permissions": [
            "TWEET_VIEW", "TWEET_SHARE",
            "TWEET_EDIT_OWN", "TWEET_DELETE_OWN",
            "USER_VIEW", "USER_BAN", "USER_UNBAN",
            "ADMIN_PANEL",
        ],
    },
    "admin": {
        "display_name": "Admin",
        "permissions": [
            "TWEET_CREATE", "TWEET_VIEW", "TWEET_SHARE",
            "TWEET_EDIT_OWN", "TWEET_EDIT_ANY",
            "TWEET_DELETE_OWN", "TWEET_DELETE_ANY",
            "USER_VIEW", "USER_BAN", "USER_UNBAN",
            "USER_MANAGE_ROLES", "ADMIN_PANEL",
        ],
    },
}


def seed_permissions(apps, schema_editor):
    Permission = apps.get_model("accounts", "Permission")
    for code, name, description in PERMISSIONS:
        Permission.objects.get_or_create(
            code=code,
            defaults={"name": name, "description": description},
        )


def seed_roles(apps, schema_editor):
    Permission = apps.get_model("accounts", "Permission")
    Role = apps.get_model("accounts", "Role")

    for role_name, role_data in ROLES.items():
        role, _ = Role.objects.get_or_create(
            name=role_name,
            defaults={"display_name": role_data["display_name"]},
        )
        perm_codes = role_data["permissions"]
        permissions = Permission.objects.filter(code__in=perm_codes)
        role.permissions.set(permissions)


def remove_seed(apps, schema_editor):
    Role = apps.get_model("accounts", "Role")
    Permission = apps.get_model("accounts", "Permission")
    Role.objects.all().delete()
    Permission.objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0001_initial"),
    ]

    operations = [
        migrations.RunPython(seed_permissions, remove_seed),
        migrations.RunPython(seed_roles, remove_seed),
    ]
