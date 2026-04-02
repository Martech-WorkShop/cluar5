#!/bin/bash
# publish-dockerhub.sh — Build, test, then push images to Docker Hub.
#
# Publishes to ${DOCKERHUB_USER}/${PROJECT_NAME}:
#   dev, dev-<sha>
#   builder-base, builder-base-<sha>
#
# Environment variables:
#   SKIP_BUILD=1    Skip image build (use existing local images). NOT safe before
#                   publishing unless you are certain images are current.
#   SKIP_TESTS=1    Skip test suite. NOT safe before publishing.
#   DRY_RUN=1       Print what would be pushed without actually pushing.
#
# Run from repo root:
#   bash workshop/scripts/publish-dockerhub.sh

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
SKIP_BUILD="${SKIP_BUILD:-0}"
SKIP_TESTS="${SKIP_TESTS:-0}"

[ "$DRY_RUN" = "1" ] && warn "DRY RUN — no images will actually be pushed"

GIT_SHA=$(git rev-parse --short HEAD)
DEV_IMAGE="${PROJECT_NAME}-dev"
BUILDER_IMAGE="${PROJECT_NAME}-builder-base"
HUB="${DOCKERHUB_USER}/${PROJECT_NAME}"

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

# Must be logged in to Docker Hub
if [ "$DRY_RUN" != "1" ]; then
  if ! docker info 2>/dev/null | grep -q "Username"; then
    # Try a pull to see if credentials are cached
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

if [ "$SKIP_BUILD" = "1" ]; then
  warn "Skipping image build (SKIP_BUILD=1)"
else
  info "Building ${BUILDER_IMAGE}..."
  make build-base || abort "Builder-base build failed."
  ok "${BUILDER_IMAGE} built"

  info "Building ${DEV_IMAGE}..."
  make dev || abort "Dev image build failed."
  ok "${DEV_IMAGE} built"
fi

# ── Tests ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}── Running test suites ─────────────────────────────${NC}"

if [ "$SKIP_TESTS" = "1" ]; then
  warn "Skipping tests (SKIP_TESTS=1)"
else
  SKIP_BUILD=1 bash workshop/tests/run-all.sh || abort "Tests failed. Fix before publishing."
fi

# ── Tag ───────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}── Tagging images ──────────────────────────────────${NC}"

tag_image() {
  local src="$1" dst="$2"
  info "  docker tag ${src} ${dst}"
  [ "$DRY_RUN" != "1" ] && docker tag "$src" "$dst"
}

tag_image "${DEV_IMAGE}"     "${HUB}:dev"
tag_image "${DEV_IMAGE}"     "${HUB}:dev-${GIT_SHA}"
tag_image "${BUILDER_IMAGE}" "${HUB}:builder-base"
tag_image "${BUILDER_IMAGE}" "${HUB}:builder-base-${GIT_SHA}"
ok "Tagged dev and builder-base with :<name> and :<name>-${GIT_SHA}"

# ── Push ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}── Pushing to Docker Hub ───────────────────────────${NC}"

push_image() {
  local tag="$1"
  info "  docker push ${tag}"
  [ "$DRY_RUN" != "1" ] && docker push "$tag"
}

push_image "${HUB}:dev"
push_image "${HUB}:dev-${GIT_SHA}"
push_image "${HUB}:builder-base"
push_image "${HUB}:builder-base-${GIT_SHA}"

echo ""
if [ "$DRY_RUN" = "1" ]; then
  echo -e "${YELLOW}${BOLD}Dry run complete — nothing was pushed.${NC}"
else
  ok "Pushed ${HUB}:dev"
  ok "Pushed ${HUB}:dev-${GIT_SHA}"
  ok "Pushed ${HUB}:builder-base"
  ok "Pushed ${HUB}:builder-base-${GIT_SHA}"
  echo ""
  echo -e "${GREEN}${BOLD}Docker Hub publish complete.${NC}"
fi
