#!/bin/bash
# publish-all.sh — Build, test, then publish to both GitHub and Docker Hub.
#
# Builds images and runs tests exactly once, then pushes to both platforms.
# Use this instead of running publish-github.sh and publish-dockerhub.sh
# separately to avoid building and testing twice.
#
# Environment variables:
#   DRY_RUN=1    Print what would be pushed without actually pushing.
#
# Run from repo root:
#   bash workshop/scripts/publish-all.sh

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

DRY_RUN="${DRY_RUN:-0}"
[ "$DRY_RUN" = "1" ] && warn "DRY RUN — nothing will actually be pushed"

echo ""
echo -e "${BOLD}${BLUE}════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  Publish: GitHub + Docker Hub${NC}"
echo -e "${BOLD}${BLUE}════════════════════════════════════════${NC}"

# ── Pre-checks ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}── Pre-publish checks ──────────────────────────────${NC}"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$BRANCH" = "main" ] || abort "Not on main (currently on '$BRANCH'). Merge first."
ok "On main branch"

if ! git diff --quiet || ! git diff --cached --quiet; then
  abort "Uncommitted changes present. Commit or stash before publishing."
fi
ok "Working tree is clean"

if ! git remote get-url origin > /dev/null 2>&1; then
  abort "No 'origin' remote configured."
fi
ok "GitHub remote: $(git remote get-url origin)"

if [ "$DRY_RUN" != "1" ]; then
  if ! docker info 2>/dev/null | grep -q "Username"; then
    if ! docker pull hello-world > /dev/null 2>&1; then
      abort "Not logged in to Docker Hub. Run: docker login"
    fi
  fi
  ok "Docker Hub credentials present"
else
  warn "Skipping Docker Hub login check (dry run)"
fi

# ── Build ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}── Building images ─────────────────────────────────${NC}"
info "Building ${PROJECT_NAME}-builder-base..."
make build-base || abort "Builder-base build failed."
ok "${PROJECT_NAME}-builder-base built"

info "Building ${PROJECT_NAME}-dev..."
make dev || abort "Dev image build failed."
ok "${PROJECT_NAME}-dev built"

# ── Tests ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}── Running test suites ─────────────────────────────${NC}"
SKIP_BUILD=1 bash workshop/tests/run-all.sh || abort "Tests failed. Fix before publishing."

# ── Push to GitHub ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}── Pushing to GitHub ───────────────────────────────${NC}"
if [ "$DRY_RUN" = "1" ]; then
  warn "DRY RUN: would run: git push origin main"
else
  git push origin main
  ok "Pushed to $(git remote get-url origin)"
fi

# ── Push to Docker Hub ────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}── Pushing to Docker Hub ───────────────────────────${NC}"
DRY_RUN="$DRY_RUN" SKIP_BUILD=1 SKIP_TESTS=1 bash workshop/scripts/publish-dockerhub.sh

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}════════════════════════════════════════${NC}"
if [ "$DRY_RUN" = "1" ]; then
  echo -e "${YELLOW}${BOLD}Dry run complete — nothing was pushed.${NC}"
else
  echo -e "${GREEN}${BOLD}Published to GitHub and Docker Hub.${NC}"
fi
