import random
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from accounts.models import Tweet, Role

User = get_user_model()

TWEET_CONTENTS = [
    "Just shipped a new feature! The team has been working on this for weeks. #launch",
    "Beautiful sunrise this morning. Sometimes you need to step away from the screen.",
    "Hot take: tabs are better than spaces. Fight me.",
    "Working from my favorite coffee shop today. The ambiance really helps with focus.",
    "Just discovered a memory leak in production. The joys of mobile development.",
    "Reading 'Designing Data-Intensive Applications' — highly recommend for backend engineers.",
    "Our database migration completed successfully. 0 downtime, 0 data loss. Perfect.",
    "Anyone else find themselves debugging in their dreams? Had a dream about a null pointer.",
    "New office plant update: it's still alive after 2 weeks. Personal record.",
    "Pair programming is underrated. Just solved a 3-day bug in 20 minutes with a colleague.",
    "Deployed to production on a Friday. Living dangerously.",
    "The best code is no code at all. Every line you don't write is a line you don't maintain.",
    "Finally understand why everyone loves VS Code extensions. Game changer.",
    "Our load tests passed with flying colors. Ready for launch week!",
    "Spent 4 hours debugging a CSS issue. It was a missing semicolon.",
    "Remote work tip: separate your workspace from your living space. Even if it's just a corner.",
    "Just got my first contribution merged into an open source project! 🎉",
    "The best meetings are the ones that could have been an email. And vice versa.",
    "Upgraded our CI pipeline. Build times went from 12 minutes to 3 minutes.",
    "Debugging tip: add console.log everywhere, then remove them all. Works 60% of the time.",
    "Code review culture matters. Be kind, be specific, be helpful.",
    "Our API handles 10k requests per second now. Started at 100 six months ago.",
    "Learned about event-driven architecture today. Everything clicks now.",
    "The key to good variable naming is empathy for the next developer.",
    "Migrated from REST to GraphQL. Frontend team is thrilled. Backend team is tired.",
    "Unit tests saved us from a regression that would have affected 50k users.",
    "Sometimes the best architecture is the simplest one that works.",
    "Just realized our monitoring has been silent for 3 days. That either means everything is fine or everything is broken.",
    "Documentation is a love letter to your future self.",
    "Refactored a 500-line function into 10 small functions. Feels like therapy.",
    "TIL: Django's select_related and prefetch_related can cut query count from 200 to 3.",
    "Automated our deployment process. No more manual SSH and crossing fingers.",
    "Good error messages are worth their weight in gold.",
    "The best time to fix a bug is during code review. The second best time is now.",
    "Implemented rate limiting today. Our API went from overwhelmed to chill.",
    "Sleep is the best debugging tool. The solution always comes in the morning.",
    "Wrote tests first, then implementation. TDD feels slow until it saves you.",
    "Our monitoring dashboard went from 0 to 47 metrics. Can't look away.",
    "Sometimes you just need to delete the whole file and start fresh.",
    "Shipping imperfect code is better than shipping perfect code never.",
    "Redis caching reduced our API response time from 800ms to 12ms.",
    "The most underrated skill in programming: knowing when to ask for help.",
    "Set up a staging environment that mirrors production. Saved us twice this week.",
    "Git bisect is the most powerful tool nobody talks about.",
    "Clean code is not about following rules. It's about communicating intent.",
    "Just discovered our app works offline. We didn't even build that feature.",
    "The best security practice: assume everything is a threat until proven otherwise.",
    "Automated our test suite to run on every PR. Quality went up, bugs went down.",
    "Learning to say 'I don't know' is a senior engineer's superpower.",
    "Wrote a migration to fix 10k corrupted records. Django made it painless.",
]

USERS_DATA = [
    {
        "email": "admin@example.com",
        "username": "admin",
        "password": "admin123!",
        "first_name": "Admin",
        "last_name": "User",
        "role_name": "admin",
        "is_staff": True,
        "is_superuser": True,
    },
    {
        "email": "staff@example.com",
        "username": "staff_user",
        "password": "staff123!",
        "first_name": "Staff",
        "last_name": "Member",
        "role_name": "staff",
        "is_staff": True,
        "is_superuser": False,
    },
    {
        "email": "mod@example.com",
        "username": "moderator",
        "password": "mod123!",
        "first_name": "Mod",
        "last_name": "erator",
        "role_name": "moderator",
        "is_staff": False,
        "is_superuser": False,
    },
    {
        "email": "alice@example.com",
        "username": "alice",
        "password": "alice123!",
        "first_name": "Alice",
        "last_name": "Johnson",
        "role_name": "user",
        "is_staff": False,
        "is_superuser": False,
    },
    {
        "email": "bob@example.com",
        "username": "bob",
        "password": "bob123!",
        "first_name": "Bob",
        "last_name": "Smith",
        "role_name": "user",
        "is_staff": False,
        "is_superuser": False,
    },
    {
        "email": "charlie@example.com",
        "username": "charlie",
        "password": "charlie123!",
        "first_name": "Charlie",
        "last_name": "Brown",
        "role_name": "user",
        "is_staff": False,
        "is_superuser": False,
        "is_active": False,
    },
]


class Command(BaseCommand):
    help = "Seed the database with demo users and tweets"

    def handle(self, *args, **options):
        self.stdout.write("Seeding database...")

        for user_data in USERS_DATA:
            role_name = user_data.pop("role_name")
            password = user_data.pop("password")
            is_active = user_data.pop("is_active", True)

            user, created = User.objects.get_or_create(
                email=user_data["email"],
                defaults={**user_data, "is_active": is_active},
            )
            if created:
                user.set_password(password)
                user.save()

            role = Role.objects.filter(name=role_name).first()
            if role:
                user.role = role
                user.save()

            status_text = "created" if created else "already exists"
            active_text = "" if is_active else " [BANNED]"
            self.stdout.write(f"  User {user.email} ({role_name}) - {status_text}{active_text}")

        users = list(User.objects.filter(is_active=True).exclude(is_superuser=True))

        created_count = 0
        for i, content in enumerate(TWEET_CONTENTS):
            author = users[i % len(users)]
            tweet, created = Tweet.objects.get_or_create(
                author=author,
                content=content,
            )
            if created:
                created_count += 1

        self.stdout.write(f"\nCreated {created_count} tweets.")
        self.stdout.write(self.style.SUCCESS("Database seeded successfully!"))
