#!/usr/bin/env bash
#
# start-local-stack.sh
#
# Runs the SpinQuest app locally: Postgres and Redis in Docker, the Backend API
# on http://localhost:3000 and the Vite frontend on http://localhost:3001.
#
# Usage:
#   ./start-local-stack.sh            start everything (same as "up")
#   ./start-local-stack.sh up cards   start the cards product instead of casino
#   ./start-local-stack.sh down       stop Postgres and Redis
#   ./start-local-stack.sh check      report env keys the local stack needs but .env lacks
#
# First run creates Backend/.env and spinquest-frontend/.env from each repo's
# .env.example plus the local overrides below. An existing .env is never edited.
#
# Full setup notes: Notion page "Running SpinQuest locally" (https://app.notion.com/p/417a274ca95d81d585afdd458875ddc7).

# The workspace holds the Backend and spinquest-frontend checkouts. Resolution
# order: SPINQUEST_WORKSPACE_DIR, the script's own folder, ~/Desktop/work/spinquest.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "${SPINQUEST_WORKSPACE_DIR:-}" ]; then
  WORKSPACE_DIR="$SPINQUEST_WORKSPACE_DIR"
elif [ -d "$SCRIPT_DIR/Backend" ]; then
  WORKSPACE_DIR="$SCRIPT_DIR"
else
  WORKSPACE_DIR="$HOME/Desktop/work/spinquest"
fi
if [ ! -d "$WORKSPACE_DIR/Backend" ] || [ ! -d "$WORKSPACE_DIR/spinquest-frontend" ]; then
  printf 'error: no Backend and spinquest-frontend in %s; set SPINQUEST_WORKSPACE_DIR\n' "$WORKSPACE_DIR" >&2
  exit 1
fi
BACKEND_DIR="$WORKSPACE_DIR/Backend"
FRONTEND_DIR="$WORKSPACE_DIR/spinquest-frontend"
API_ORIGIN="http://localhost:3000"
APP_ORIGIN="http://localhost:3001"
REQUIRED_NODE_MAJOR=24
# Staging GeoComply SDK, the value the frontend deploy workflows write.
GEOCOMPLY_STAGING_SDK_URL="https://stg-cdn.geocomply.com/264/gc-html5.js"

# Keys the Backend reads with no default that .env.example does not define.
# A missing one throws the first time the owning service is constructed.
BACKEND_PLACEHOLDER_KEYS=(
  APPLE_APP_ID APPLE_SERVICE_ID
  GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET
  META_CLIENT_ID META_CLIENT_SECRET
  RECENT_CATEGORY_ID
  S3_PRIVATE_ACCESS_KEY_ID S3_PRIVATE_SECRET_ACCESS_KEY
  S3_PUBLIC_ACCESS_KEY_ID S3_PUBLIC_SECRET_ACCESS_KEY
)
# Keys the frontend env schema requires that its .env.example does not define.
FRONTEND_PLACEHOLDER_KEYS=(VITE_APP_INTERCOM_APP_ID)

print_step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
print_warning() { printf '\033[1;33mwarning:\033[0m %s\n' "$1" >&2; }
exit_with_error() {
  printf '\033[1;31merror:\033[0m %s\n' "$1" >&2
  exit 1
}

# Replaces KEY in an env file, or appends it when absent.
write_env_value() {
  local env_file="$1" key="$2" value="$3" scratch_file
  scratch_file="$(mktemp)"
  grep -v "^${key}=" "$env_file" >"$scratch_file" || true
  printf '%s=%s\n' "$key" "$value" >>"$scratch_file"
  mv "$scratch_file" "$env_file"
}

has_env_key() { grep -q "^${2}=" "$1"; }

# The frontend pins pnpm 10.34.5 in package.json. A global pnpm 11 refuses to
# switch to it under the repo's trustPolicy, so corepack supplies the pinned
# version, as the frontend README and Dockerfile do. Must run from FRONTEND_DIR.
run_frontend_pnpm() { COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack pnpm "$@"; }

create_backend_env() {
  local env_file="$BACKEND_DIR/.env" key
  cp "$BACKEND_DIR/.env.example" "$env_file"
  write_env_value "$env_file" API_URL "$API_ORIGIN"
  write_env_value "$env_file" APP_URL "$APP_ORIGIN"
  write_env_value "$env_file" CORS_ORIGINS "[\"$APP_ORIGIN\",\"$API_ORIGIN\"]"
  write_env_value "$env_file" TURNSTILE_HOSTNAMES "spinquest.com,localhost"
  write_env_value "$env_file" MFA_SECRET_ENC_KEY "$(openssl rand -hex 32)"
  write_env_value "$env_file" OPTIMOVE_BRAND_ID 0
  for key in "${BACKEND_PLACEHOLDER_KEYS[@]}"; do
    write_env_value "$env_file" "$key" dev
  done
  echo "created Backend/.env from .env.example with local overrides"
}

create_frontend_env() {
  local env_file="$FRONTEND_DIR/.env" key
  cp "$FRONTEND_DIR/.env.example" "$env_file"
  # .env.example has no trailing newline, so add one before appending keys.
  [ -n "$(tail -c1 "$env_file")" ] && echo >>"$env_file"
  write_env_value "$env_file" VITE_APP_API_URL "$API_ORIGIN"
  # index.html uses this as a <script src>; a blank value crashes Vite's HTML transform.
  write_env_value "$env_file" VITE_APP_GEOCOMPLY_URL "$GEOCOMPLY_STAGING_SDK_URL"
  for key in "${FRONTEND_PLACEHOLDER_KEYS[@]}"; do
    write_env_value "$env_file" "$key" ""
  done
  echo "created spinquest-frontend/.env from .env.example with local overrides"
}

# Prints the names (never the values) of keys an existing .env is missing.
report_missing_env_keys() {
  local env_file="$1" key missing_count=0
  shift
  for key in "$@"; do
    if ! has_env_key "$env_file" "$key"; then
      print_warning "${env_file#"$WORKSPACE_DIR"/} is missing $key"
      missing_count=$((missing_count + 1))
    fi
  done
  return "$missing_count"
}

check_env_files() {
  local missing_total=0
  report_missing_env_keys "$BACKEND_DIR/.env" \
    "${BACKEND_PLACEHOLDER_KEYS[@]}" MFA_SECRET_ENC_KEY CORS_ORIGINS \
    TURNSTILE_SECRET_KEY POSTGRES_HOST POSTGRES_PORT POSTGRES_DB \
    POSTGRES_USER POSTGRES_PASSWORD REDIS_HOST REDIS_PORT TIMEZONE ||
    missing_total=$((missing_total + $?))
  report_missing_env_keys "$FRONTEND_DIR/.env" \
    "${FRONTEND_PLACEHOLDER_KEYS[@]}" VITE_APP_VERIFF_API_KEY \
    VITE_APP_SENTRY_DSN VITE_APP_PUBLIC_POSTHOG_KEY \
    VITE_APP_PUBLIC_POSTHOG_HOST VITE_APP_AEROPAY_LOCATION_ID \
    VITE_APP_LINK_MONEY_MERCHANT_ID VITE_APP_TURNSTILE_SITE_KEY ||
    missing_total=$((missing_total + $?))
  if ! grep -q "^CORS_ORIGINS=.*$APP_ORIGIN" "$BACKEND_DIR/.env"; then
    print_warning "Backend/.env CORS_ORIGINS does not list $APP_ORIGIN; the browser will block API calls"
  fi
  if ! grep -q "^VITE_APP_GEOCOMPLY_URL=.*[^[:space:]]" "$FRONTEND_DIR/.env"; then
    print_warning "spinquest-frontend/.env VITE_APP_GEOCOMPLY_URL is blank; Vite fails on index.html (use $GEOCOMPLY_STAGING_SDK_URL)"
  fi
  [ "$missing_total" -eq 0 ] && echo "env files have every key the local stack needs"
  return 0
}

ensure_env_files() {
  print_step "Env files"
  [ -f "$BACKEND_DIR/.env" ] || create_backend_env
  [ -f "$FRONTEND_DIR/.env" ] || create_frontend_env
  check_env_files
}

select_node_version() {
  print_step "Node $REQUIRED_NODE_MAJOR"
  if [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
    # shellcheck disable=SC1091
    . "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
    nvm use "$REQUIRED_NODE_MAJOR" >/dev/null ||
      exit_with_error "run: nvm install $REQUIRED_NODE_MAJOR"
  fi
  local node_major
  node_major="$(node -p 'process.versions.node.split(".")[0]')"
  [ "$node_major" = "$REQUIRED_NODE_MAJOR" ] ||
    exit_with_error "Node $REQUIRED_NODE_MAJOR is required (both .nvmrc files pin 24.x); found $(node -v)"
  command -v pnpm >/dev/null || exit_with_error "pnpm not found; run: npm install -g pnpm"
  command -v corepack >/dev/null || exit_with_error "corepack not found; it ships with Node $REQUIRED_NODE_MAJOR"
  echo "node $(node -v), pnpm $(pnpm -v)"
}

start_docker_daemon() {
  print_step "Docker"
  command -v docker >/dev/null || exit_with_error "docker CLI not found; install Docker Desktop"
  if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon is not running; starting Docker Desktop"
    open -a Docker || exit_with_error "could not start Docker Desktop"
    local waited_seconds=0
    until docker info >/dev/null 2>&1; do
      [ "$waited_seconds" -ge 120 ] && exit_with_error "Docker did not start within 120s"
      sleep 2
      waited_seconds=$((waited_seconds + 2))
    done
  fi
  echo "docker daemon is up"
}

install_dependencies() {
  if [ ! -d "$BACKEND_DIR/node_modules" ]; then
    print_step "Installing dependencies in Backend"
    (cd "$BACKEND_DIR" && pnpm install --frozen-lockfile) ||
      exit_with_error "pnpm install failed in Backend"
  fi
  if [ ! -d "$FRONTEND_DIR/node_modules" ]; then
    print_step "Installing dependencies in spinquest-frontend"
    (cd "$FRONTEND_DIR" && run_frontend_pnpm install --frozen-lockfile) ||
      exit_with_error "pnpm install failed in spinquest-frontend"
  fi
}

# docker-compose.yaml mounts $PWD/data, so compose must run from Backend/.
start_data_services() {
  print_step "Postgres and Redis"
  (cd "$BACKEND_DIR" && docker compose up -d) || exit_with_error "docker compose up failed"
  local waited_seconds=0
  until (cd "$BACKEND_DIR" && docker compose exec -T postgres \
    sh -c 'pg_isready -q -U "$POSTGRES_USER" -d "$POSTGRES_DB"') 2>/dev/null; do
    [ "$waited_seconds" -ge 60 ] && exit_with_error "Postgres was not ready within 60s"
    sleep 1
    waited_seconds=$((waited_seconds + 1))
  done
  echo "postgres is accepting connections"
}

run_database_migrations() {
  print_step "Database migrations"
  (cd "$BACKEND_DIR" && pnpm db:migrate) || exit_with_error "migrations failed"
}

prefix_output() { awk -v tag="$1" '{ print tag " " $0; fflush() }'; }

stop_app_processes() {
  trap - INT TERM EXIT
  printf '\nstopping API and frontend (Postgres and Redis keep running; use "down" to stop them)\n'
  kill 0 2>/dev/null
}

start_app_processes() {
  local product="$1"
  print_step "API on $API_ORIGIN, frontend ($product) on $APP_ORIGIN. Ctrl-C stops both"
  trap stop_app_processes INT TERM EXIT
  (cd "$BACKEND_DIR" && FORCE_COLOR=1 pnpm start 2>&1 |
    prefix_output $'\033[35m[api]\033[0m') &
  (cd "$FRONTEND_DIR" && FORCE_COLOR=1 run_frontend_pnpm "dev:$product" 2>&1 |
    prefix_output $'\033[32m[web]\033[0m') &
  wait
}

start_stack() {
  local product="${1:-casino}"
  case "$product" in
    casino | cards) ;;
    *) exit_with_error "unknown product \"$product\" (casino or cards)" ;;
  esac
  select_node_version
  ensure_env_files
  start_docker_daemon
  install_dependencies
  start_data_services
  run_database_migrations
  start_app_processes "$product"
}

stop_data_services() {
  print_step "Stopping Postgres and Redis"
  (cd "$BACKEND_DIR" && docker compose down)
}

case "${1:-up}" in
  up) start_stack "${2:-}" ;;
  down) stop_data_services ;;
  check) check_env_files ;;
  *) exit_with_error "usage: $(basename "$0") [up [casino|cards] | down | check]" ;;
esac
