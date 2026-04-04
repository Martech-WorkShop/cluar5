#!/bin/bash
# publish-github.sh — Build, test, then push main to GitHub.
#
# Refuses to push if:
#   - not on main branch
#   - working tree has uncommitted changes
#   - any test suite fails
#
# Run from repo root:
#   bash workshop/scripts/publish-github.sh

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source PROJECT.conf

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}$*${NC}"; }
ok()    { echo -e "${GREEN}✓  $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠  $*${NC}"; }
abort() { echo -e "${RED}${BOLD}✗  $*${NC}"; exit 1; }

echo ""
echo -e "${BOLD}${BLUE}── Pre-publish checks ──────────────────────────────${NC}"

# Must be on main
BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$BRANCH" = "main" ] || abort "Not on main (currently on '$BRANCH'). Merge first."
ok "On main branch"

# Working tree must be clean
if ! git diff --quiet || ! git diff --cached --quiet; then
  abort "Uncommitted changes present. Commit or stash before publishing."
fi
ok "Working tree is clean"

# Check remote exists
if ! git remote get-url origin > /dev/null 2>&1; then
  abort "No 'origin' remote configured."
fi
ok "Remote 'origin' is configured: $(git remote get-url origin)"

echo ""
echo -e "${BOLD}${BLUE}── Building images ─────────────────────────────────${NC}"
info "Building ${PROJECT_NAME}-builder-base..."
make build-base || abort "Builder-base build failed."
ok "${PROJECT_NAME}-builder-base built"

info "Building ${PROJECT_NAME}-dev..."
make dev || abort "Dev image build failed."
ok "${PROJECT_NAME}-dev built"

echo ""
echo -e "${BOLD}${BLUE}── Running test suites ─────────────────────────────${NC}"
if ! bash workshop/tests/run-all.sh; then
  abort "Tests failed. Fix before publishing."
fi

echo ""
echo -e "${BOLD}${BLUE}── Pushing to GitHub ───────────────────────────────${NC}"
info "Pushing main to origin..."
git push origin main
ok "Pushed to $(git remote get-url origin)"

echo ""
echo -e "${GREEN}${BOLD}Published successfully.${NC}"
