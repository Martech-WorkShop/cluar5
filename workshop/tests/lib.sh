#!/bin/bash
# lib.sh — Shared helpers for all test scripts.
# Source this file at the top of each test script.

# ── Colours ───────────────────────────────────────────────────────────────────
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# ── Counters ──────────────────────────────────────────────────────────────────
_PASS=0
_WARN=0
_FAIL=0

# ── Output helpers ────────────────────────────────────────────────────────────
info()    { echo -e "${BLUE}$*${NC}"; }
section() { echo -e "\n${BOLD}${BLUE}── $* ──────────────────────────────${NC}"; }
pass()    { echo -e "  ${GREEN}✓${NC}  $*"; _PASS=$((_PASS + 1)); }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $*"; _WARN=$((_WARN + 1)); }
fail()    { echo -e "  ${RED}✗${NC}  $*"; _FAIL=$((_FAIL + 1)); }

# check NAME EXPECTED ACTUAL
# Passes if ACTUAL == EXPECTED, fails otherwise.
check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$name"
  else
    fail "$name  →  expected '${expected}'  got '${actual:-<empty>}'"
  fi
}

# check_contains NAME SUBSTRING ACTUAL
# Passes if ACTUAL contains SUBSTRING.
check_contains() {
  local name="$1" substr="$2" actual="$3"
  if echo "$actual" | grep -qF "$substr"; then
    pass "$name"
  else
    fail "$name  →  expected to contain '${substr}'  got '${actual:-<empty>}'"
  fi
}

# ── Summary ───────────────────────────────────────────────────────────────────
# Call at the end of every test script.
summary() {
  local suite="${1:-Tests}"
  echo ""
  echo -e "${BOLD}${BLUE}Results: ${suite}${NC}"
  echo -e "  ${GREEN}Passed:${NC}  ${_PASS}"
  [ "$_WARN" -gt 0 ] && echo -e "  ${YELLOW}Warnings:${NC} ${_WARN}"
  [ "$_FAIL" -gt 0 ] && echo -e "  ${RED}Failed:${NC}  ${_FAIL}"
  echo ""
  if [ "$_FAIL" -gt 0 ]; then
    echo -e "${RED}${BOLD}FAIL${NC} — ${_FAIL} test(s) failed"
    return 1
  else
    echo -e "${GREEN}${BOLD}PASS${NC}"
    return 0
  fi
}

# ── Repo root ─────────────────────────────────────────────────────────────────
REPO_ROOT="$(git rev-parse --show-toplevel)"
source "${REPO_ROOT}/PROJECT.conf"
DEV_IMAGE="${PROJECT_NAME}-dev"
BUILDER_IMAGE="${PROJECT_NAME}-builder-base"
COMPOSE_FILE="${REPO_ROOT}/workshop/docker/docker-compose.yml"

# ── Temp file cleanup ─────────────────────────────────────────────────────────
_TMPDIRS=()
make_tmpdir() {
  local d
  d=$(mktemp -d)
  _TMPDIRS+=("$d")
  echo "$d"
}
_cleanup_tmpdirs() {
  for d in "${_TMPDIRS[@]:-}"; do
    [ -d "$d" ] && rm -rf "$d"
  done
}
trap _cleanup_tmpdirs EXIT
