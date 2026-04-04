#!/bin/bash
# templateCommit.sh — Commit and push template initialization changes.
#
# Fired by .devcontainer/devcontainer.json postAttachCommand.
# Runs after VS Code attaches, so host credentials are forwarded.
#
# Safe to run multiple times — skips if nothing to commit.

set -e

source PROJECT.conf

NEEDS_COMMIT=false
NEEDS_PUSH=false

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    NEEDS_COMMIT=true
fi

# Check for unpushed commits
if [ -n "$(git log --oneline @{u}..HEAD 2>/dev/null)" ]; then
    NEEDS_PUSH=true
fi

if [ "$NEEDS_COMMIT" = "false" ] && [ "$NEEDS_PUSH" = "false" ]; then
    exit 0
fi

echo ""
git config user.name "${GITHUB_USER}"
git config user.email "${GITHUB_USER}@users.noreply.github.com"

if [ "$NEEDS_COMMIT" = "true" ]; then
    echo "Committing initialization changes..."
    git add -A
    git commit -m "chore: initialize project as ${PROJECT_NAME}"
fi

if git push; then
    echo "Pushed to GitHub."
else
    echo "Push failed — run 'git push' manually."
fi
echo ""
