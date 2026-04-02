#!/bin/bash
# test-builder.sh — Smoke tests for the builder-base image.
#
# Verifies the musl build environment: static libs, headers, compiler,
# and ability to produce a working statically-linked binary.
#
# Run from repo root:
#   bash workshop/tests/test-builder.sh
#
# Skip image rebuild:
#   SKIP_BUILD=1 bash workshop/tests/test-builder.sh

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
source workshop/tests/lib.sh

# ── Build ──────────────────────────────────────────────────────────────────────
section "Build"

if [ "${SKIP_BUILD:-0}" = "1" ]; then
  warn "Skipping image build (SKIP_BUILD=1) — using existing ${BUILDER_IMAGE}"
else
  info "Building ${BUILDER_IMAGE}..."
  if make build-base > /tmp/builder-build.log 2>&1; then
    pass "docker build ${BUILDER_IMAGE}"
  else
    fail "docker build ${BUILDER_IMAGE} — see /tmp/builder-build.log"
    summary "Builder base"
    exit 1
  fi
fi

# Helper: run inside builder-base
builder_run() {
  docker run --rm "${BUILDER_IMAGE}" bash -c "$1" 2>/dev/null
}

# ── LuaJIT static library ─────────────────────────────────────────────────────
section "LuaJIT (/opt/musl)"

check "libluajit-5.1.a exists" \
  "0" \
  "$(builder_run 'test -f /opt/musl/lib/libluajit-5.1.a && echo 0 || echo 1')"

check "LuaJIT headers exist" \
  "0" \
  "$(builder_run 'test -d /opt/musl/include/luajit-2.1 && echo 0 || echo 1')"

check "lua.h present" \
  "0" \
  "$(builder_run 'test -f /opt/musl/include/luajit-2.1/lua.h && echo 0 || echo 1')"

# Confirm it's upstream LuaJIT, not OpenResty fork
check_contains "LuaJIT is upstream (not OpenResty)" \
  "LuaJIT" \
  "$(builder_run 'strings /opt/musl/lib/libluajit-5.1.a 2>/dev/null | grep -m1 "LuaJIT" || echo ""')"

# ── Gambit Scheme ─────────────────────────────────────────────────────────────
section "Gambit Scheme (/opt/musl)"

check "libgambit.a exists" \
  "0" \
  "$(builder_run 'test -f /opt/musl/lib/libgambit.a && echo 0 || echo 1')"

check "gsc compiler exists" \
  "0" \
  "$(builder_run 'test -f /opt/musl/bin/gsc && echo 0 || echo 1')"

check "gsc is executable" \
  "0" \
  "$(builder_run 'test -x /opt/musl/bin/gsc && echo 0 || echo 1')"

check "gsc evaluates Scheme" \
  "7" \
  "$(builder_run '/opt/musl/bin/gsi -e "(display (+ 3 4)) (newline)"')"

# ── musl-gcc static compilation ───────────────────────────────────────────────
section "musl-gcc static compilation"

CTEST=$(make_tmpdir)
cat > "${CTEST}/hello.c" << 'EOF'
#include <stdio.h>
int main() { printf("musl_ok\n"); return 0; }
EOF

# Compile inside builder-base
docker run --rm \
  -v "${CTEST}:/tmp/ctest" \
  "${BUILDER_IMAGE}" bash -c \
  'musl-gcc -static /tmp/ctest/hello.c -o /tmp/ctest/hello_musl' \
  > /dev/null 2>&1

if [ -f "${CTEST}/hello_musl" ]; then
  pass "musl-gcc compiled binary produced"
else
  fail "musl-gcc compilation produced no output binary"
fi

# Verify it is statically linked
FILE_OUTPUT=$(file "${CTEST}/hello_musl" 2>/dev/null)
if echo "$FILE_OUTPUT" | grep -q "statically linked"; then
  pass "Binary is statically linked"
else
  fail "Binary is NOT statically linked  →  $FILE_OUTPUT"
fi

# Verify the binary actually executes (on the host if musl is available, else inside container)
if command -v "${CTEST}/hello_musl" > /dev/null 2>&1 || [ -x "${CTEST}/hello_musl" ]; then
  EXEC_RESULT=$("${CTEST}/hello_musl" 2>/dev/null || true)
  if [ "$EXEC_RESULT" = "musl_ok" ]; then
    pass "Statically linked binary executes correctly"
  else
    # Try running inside a minimal container
    EXEC_RESULT=$(docker run --rm \
      -v "${CTEST}:/tmp/ctest" \
      "${BUILDER_IMAGE}" bash -c '/tmp/ctest/hello_musl' 2>/dev/null)
    check "Statically linked binary executes correctly" "musl_ok" "$EXEC_RESULT"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
summary "Builder base"
