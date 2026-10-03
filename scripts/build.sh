#!/usr/bin/env bash
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}[BUILD]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ─── Check tools ──────────────────────────────────────────────────────────────
command -v docker >/dev/null 2>&1 || err "Docker is not installed."
command -v docker compose >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1 || err "Docker Compose is not installed."

# ─── Environment ──────────────────────────────────────────────────────────────
cp -n .env.example .env 2>/dev/null || true

case "${1:-help}" in
  dev)
    log "Starting development environment..."
    docker compose up --build
    ;;

  prod)
    log "Starting production environment..."
    export DEBUG=False
    docker compose --profile prod up --build -d
    ;;

  stop)
    log "Stopping all containers..."
    docker compose down
    ;;

  logs)
    docker compose logs -f --tail=100
    ;;

  test)
    log "Running backend tests..."
    docker compose run --rm backend python manage.py test accounts --verbosity=2
    log "Running Flutter tests..."
    docker run --rm -v "$(pwd):/app" -w /app ghcr.io/cirruslabs/flutter:stable flutter test
    ;;

  build-web)
    log "Building Flutter web..."
    docker run --rm -v "$(pwd):/app" -w /app ghcr.io/cirruslabs/flutter:stable \
      sh -c "flutter pub get && flutter build web --release --tree-shake-icons"
    ok "Web build: build/web/"
    ;;

  build-android)
    log "Building Android APK..."
    docker run --rm -v "$(pwd):/app" -w /app \
      --pull=always \
      ghcr.io/cirruslabs/flutter:stable \
      sh -c "flutter pub get && flutter build apk --release"
    log "Building Android AAB..."
    docker run --rm -v "$(pwd):/app" -w /app \
      ghcr.io/cirruslabs/flutter:stable \
      sh -c "flutter build appbundle --release"
    ok "APK: build/app/outputs/flutter-apk/app-release.apk"
    ok "AAB: build/app/outputs/bundle/release/app-release.aab"
    ;;

  build-ios)
    log "Building iOS (requires macOS host)..."
    flutter pub get
    flutter build ios --release --no-codesign
    ok "iOS build: build/ios/iphoneos/Runner.app"
    ;;

  backend)
    log "Building backend Docker image..."
    docker build -t auth-backend:latest ./backend/auth_demo
    ok "Backend image: auth-backend:latest"
    ;;

  frontend)
    log "Building frontend Docker image..."
    docker build -t auth-frontend:latest -f Dockerfile.frontend .
    ok "Frontend image: auth-frontend:latest"
    ;;

  migrate)
    log "Running migrations..."
    docker compose exec backend python manage.py migrate
    ok "Migrations applied."
    ;;

  createsuperuser)
    log "Creating superuser..."
    docker compose exec backend python manage.py createsuperuser
    ;;

  shell)
    docker compose exec backend python manage.py shell
    ;;

  clean)
    log "Cleaning Docker resources..."
    docker compose down -v --rmi local 2>/dev/null || true
    rm -rf build/ .dart_tool/ .pub-cache/
    ok "Cleaned."
    ;;

  help|*)
    echo ""
    echo "  Usage: ./scripts/build.sh <command>"
    echo ""
    echo "  Commands:"
    echo "    dev              Start development environment (hot reload)"
    echo "    prod             Start production environment"
    echo "    stop             Stop all containers"
    echo "    logs             Follow container logs"
    echo "    test             Run all tests (backend + flutter)"
    echo "    build-web        Build Flutter web (Docker)"
    echo "    build-android    Build Android APK + AAB (Docker)"
    echo "    build-ios        Build iOS (macOS host required)"
    echo "    backend          Build backend Docker image only"
    echo "    frontend         Build frontend Docker image only"
    echo "    migrate          Run Django migrations"
    echo "    createsuperuser  Create Django admin user"
    echo "    shell            Open Django shell"
    echo "    clean            Remove containers, volumes, build artifacts"
    echo ""
    ;;
esac
