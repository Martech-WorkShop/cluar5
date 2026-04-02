#!/bin/bash
# test-dev.sh — Smoke tests for the dev container image.
#
# Verifies that all runtimes, tools, and services installed in Dockerfile.dev
# actually work inside the container.
#
# Run from repo root:
#   bash workshop/tests/test-dev.sh
#
# Skip image rebuild (if already up to date):
#   SKIP_BUILD=1 bash workshop/tests/test-dev.sh

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
source workshop/tests/lib.sh

# ── Build ──────────────────────────────────────────────────────────────────────
section "Build"

if [ "${SKIP_BUILD:-0}" = "1" ]; then
  warn "Skipping image build (SKIP_BUILD=1) — using existing ${DEV_IMAGE}"
else
  info "Building ${DEV_IMAGE}..."
  if make dev > /tmp/dev-build.log 2>&1; then
    pass "docker build ${DEV_IMAGE}"
  else
    fail "docker build ${DEV_IMAGE} — see /tmp/dev-build.log"
    summary "Dev container"
    exit 1
  fi
fi

# Helper: run a command inside the dev container and return stdout.
dev_run() {
  docker run --rm "${DEV_IMAGE}" -c "$1" 2>/dev/null
}

# ── Lua ───────────────────────────────────────────────────────────────────────
section "Lua runtimes"

# 'lua' symlink must resolve to Lua 5.4
check "'lua' symlink → Lua 5.4" \
  "Lua 5.4" \
  "$(dev_run 'lua -v 2>&1' | grep -o 'Lua 5\.4')"

# Lua 5.4-specific feature: math.type returns 'integer' for integer values
check "Lua 5.4 native integers (math.type)" \
  "integer" \
  "$(dev_run "lua5.4 -e \"print(math.type(1))\"")"

# LuaJIT must be present and report 2.1
check_contains "LuaJIT 2.1 present" \
  "LuaJIT 2.1" \
  "$(dev_run 'luajit -v 2>&1')"

# LuaJIT must NOT respond to math.type (Lua 5.1 — this function does not exist)
check "LuaJIT is Lua 5.1 compatible (no math.type)" \
  "nil" \
  "$(dev_run "luajit -e \"print(type(math.type))\"")"

# ── Gambit Scheme ─────────────────────────────────────────────────────────────
section "Gambit Scheme"

check "gsi evaluates expression" \
  "42" \
  "$(dev_run 'gsi -e "(display (* 6 7)) (newline)"')"

# ── C toolchain ───────────────────────────────────────────────────────────────
section "C toolchain"

CTEST=$(make_tmpdir)
cat > "${CTEST}/hello.c" << 'EOF'
#include <stdio.h>
int main() { printf("c_ok\n"); return 0; }
EOF

check "gcc compiles and runs hello world" \
  "c_ok" \
  "$(docker run --rm -v "${CTEST}:/tmp/ctest" "${DEV_IMAGE}" \
     -c 'gcc /tmp/ctest/hello.c -o /tmp/ctest/hello && /tmp/ctest/hello' 2>/dev/null)"

# ── SQLite ────────────────────────────────────────────────────────────────────
section "SQLite"

check "sqlite3 CLI present" \
  "1" \
  "$(dev_run "sqlite3 :memory: 'SELECT 1'")"

check "libsqlite3-dev headers present" \
  "0" \
  "$(docker run --rm "${DEV_IMAGE}" -c \
     'test -f /usr/include/sqlite3.h && echo 0 || echo 1' 2>/dev/null)"

# ── PostgreSQL client ─────────────────────────────────────────────────────────
section "PostgreSQL client"

check_contains "psql client present" \
  "PostgreSQL" \
  "$(dev_run 'psql --version')"

check_contains "pg_isready present" \
  "pg_isready" \
  "$(dev_run 'which pg_isready')"

check "libpq-dev headers present" \
  "0" \
  "$(docker run --rm "${DEV_IMAGE}" -c \
     'test -f /usr/include/postgresql/libpq-fe.h && echo 0 || echo 1' 2>/dev/null)"

# ── H2O ───────────────────────────────────────────────────────────────────────
section "H2O HTTP server"

check_contains "h2o binary present and runs" \
  "h2o version" \
  "$(dev_run 'h2o --version 2>&1')"

check_contains "H2O built with OpenSSL" \
  "OpenSSL" \
  "$(dev_run 'h2o --version 2>&1')"

# HTTP/3 must NOT be present (deferred — requires quictls/BoringSSL)
QUIC_OUTPUT="$(dev_run 'h2o --version 2>&1 | grep -i quic || echo quic_absent')"
check "HTTP/3 (QUIC) correctly absent" \
  "quic_absent" \
  "$QUIC_OUTPUT"

# H2O must actually serve a static file via HTTP
H2O_TMPDIR=$(make_tmpdir)
echo "h2o_serve_ok" > "${H2O_TMPDIR}/index.txt"
cat > "${H2O_TMPDIR}/h2o.conf" << 'CONF'
listen:
  host: 127.0.0.1
  port: 7080
hosts:
  "127.0.0.1:7080":
    paths:
      "/":
        file.dir: /tmp/www
CONF

H2O_RESULT=$(docker run --rm \
  -v "${H2O_TMPDIR}:/tmp/www:ro" \
  -v "${H2O_TMPDIR}/h2o.conf:/tmp/h2o.conf:ro" \
  "${DEV_IMAGE}" -c '
    h2o -m worker -c /tmp/h2o.conf &
    H2O_PID=$!
    sleep 1
    RESULT=$(curl -sf http://127.0.0.1:7080/index.txt)
    kill $H2O_PID 2>/dev/null
    printf "%s" "$RESULT"
  ' 2>/dev/null)

check "H2O serves static file via HTTP" \
  "h2o_serve_ok" \
  "$H2O_RESULT"

# ── Summary ───────────────────────────────────────────────────────────────────
summary "Dev container"
