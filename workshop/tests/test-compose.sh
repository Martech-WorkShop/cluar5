#!/bin/bash
# test-compose.sh — Tests for the docker-compose setup.
#
# Verifies that the Postgres sidecar starts correctly and that data
# persists across container recreation.
#
# Run from repo root:
#   bash workshop/tests/test-compose.sh
#
# WARNING: This test starts and stops Docker containers and creates/removes
# a named volume (cluar5-test-db-data). It does NOT affect the standard
# db-data volume used during normal development.

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
source workshop/tests/lib.sh

# Use a dedicated test compose project name to avoid colliding with dev volumes
COMPOSE_PROJECT="cluar5-test"
COMPOSE_OPTS="-f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT}"

cleanup_compose() {
  docker compose ${COMPOSE_OPTS} down -v > /dev/null 2>&1 || true
}
trap cleanup_compose EXIT

# ── Config validation ─────────────────────────────────────────────────────────
section "docker-compose config"

if docker compose ${COMPOSE_OPTS} config > /dev/null 2>&1; then
  pass "docker-compose.yml is valid"
else
  fail "docker-compose.yml failed validation"
  summary "docker-compose"
  exit 1
fi

DB_SERVICE=$(docker compose ${COMPOSE_OPTS} config --services 2>/dev/null | grep '^db$' || true)
check "db service is defined" "db" "$DB_SERVICE"

# ── Postgres startup ──────────────────────────────────────────────────────────
section "Postgres sidecar startup"

info "Starting db service..."
docker compose ${COMPOSE_OPTS} up -d db > /dev/null 2>&1

# Wait up to 15 seconds for Postgres to be ready
READY=0
for i in $(seq 1 15); do
  if docker compose ${COMPOSE_OPTS} exec -T db pg_isready -U appuser > /dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 1
done

if [ "$READY" = "1" ]; then
  pass "Postgres accepts connections"
else
  fail "Postgres did not become ready within 15 seconds"
  summary "docker-compose"
  exit 1
fi

# Verify correct database and user exist
DB_CHECK=$(docker compose ${COMPOSE_OPTS} exec -T db \
  psql -U appuser -d appdb -c "SELECT 1" -t 2>/dev/null | tr -d ' \n' || true)
check "appdb database accessible as appuser" "1" "$DB_CHECK"

# ── Data persistence ──────────────────────────────────────────────────────────
section "Data persistence across container recreation"

# Write data
docker compose ${COMPOSE_OPTS} exec -T db \
  psql -U appuser -d appdb \
  -c "CREATE TABLE IF NOT EXISTS _test_ping (id serial PRIMARY KEY);" \
  > /dev/null 2>&1

docker compose ${COMPOSE_OPTS} exec -T db \
  psql -U appuser -d appdb \
  -c "INSERT INTO _test_ping DEFAULT VALUES;" \
  > /dev/null 2>&1

pass "Wrote test row to database"

# Recreate container (volume survives)
docker compose ${COMPOSE_OPTS} down > /dev/null 2>&1
docker compose ${COMPOSE_OPTS} up -d db > /dev/null 2>&1

# Wait for ready
READY=0
for i in $(seq 1 15); do
  if docker compose ${COMPOSE_OPTS} exec -T db pg_isready -U appuser > /dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 1
done

if [ "$READY" != "1" ]; then
  fail "Postgres did not restart within 15 seconds"
  summary "docker-compose"
  exit 1
fi

# Read back
ROW_COUNT=$(docker compose ${COMPOSE_OPTS} exec -T db \
  psql -U appuser -d appdb \
  -c "SELECT count(*) FROM _test_ping;" -t 2>/dev/null | tr -d ' \n' || true)

check "Data persisted across container recreation (row count = 1)" "1" "$ROW_COUNT"

# ── Teardown ──────────────────────────────────────────────────────────────────
section "Teardown"

docker compose ${COMPOSE_OPTS} down -v > /dev/null 2>&1
pass "Containers and test volumes removed"

# ── Summary ───────────────────────────────────────────────────────────────────
summary "docker-compose"
