#!/bin/bash
# templateCommit.sh — Commit and push template initialization changes.
#
# Fired by .devcontainer/devcontainer.json postAttachCommand.
# Runs after VS Code attaches, so host credentials are forwarded.
#
# Safe to run multiple times — skips if nothing to commit.

set -e

source PROJECT.conf

# Nothing to commit if working tree is clean
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    exit 0
fi

echo ""
echo "Committing initialization changes..."
git config user.name "${GITHUB_USER}"
git config user.email "${GITHUB_USER}@users.noreply.github.com"
git add -A
git commit -m "chore: initialize project as ${PROJECT_NAME}"

if git push; then
    echo "Pushed to GitHub."
else
    echo "Push failed — run 'git push' manually."
fi
echo ""
