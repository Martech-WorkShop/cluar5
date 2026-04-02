#!/bin/bash
# run-all.sh — Run all test suites and report an overall result.
#
# Run from repo root:
#   bash workshop/tests/run-all.sh
#
# Skip image rebuilds (if images are already up to date):
#   SKIP_BUILD=1 bash workshop/tests/run-all.sh

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
source workshop/tests/lib.sh

TESTS_DIR="${REPO_ROOT}/workshop/tests"
SUITE_RESULTS=()

run_suite() {
  local script="$1"
  local name="$2"
  echo ""
  echo -e "${BOLD}${BLUE}════════════════════════════════════════${NC}"
  echo -e "${BOLD}${BLUE}  Suite: ${name}${NC}"
  echo -e "${BOLD}${BLUE}════════════════════════════════════════${NC}"

  if SKIP_BUILD="${SKIP_BUILD:-0}" bash "${script}"; then
    SUITE_RESULTS+=("${GREEN}✓  ${name}${NC}")
  else
    SUITE_RESULTS+=("${RED}✗  ${name}${NC}")
    _FAIL=$((_FAIL + 1))
  fi
}

run_suite "${TESTS_DIR}/test-builder.sh" "Builder base"
run_suite "${TESTS_DIR}/test-dev.sh"     "Dev container"
run_suite "${TESTS_DIR}/test-compose.sh" "docker-compose"

# ── Overall summary ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  Overall Results${NC}"
echo -e "${BOLD}${BLUE}════════════════════════════════════════${NC}"
for result in "${SUITE_RESULTS[@]}"; do
  echo -e "  ${result}"
done
echo ""

if [ "${_FAIL}" -gt 0 ]; then
  echo -e "${RED}${BOLD}FAIL — ${_FAIL} suite(s) failed. Do not publish.${NC}"
  exit 1
else
  echo -e "${GREEN}${BOLD}ALL SUITES PASSED — safe to merge and publish.${NC}"
  exit 0
fi
