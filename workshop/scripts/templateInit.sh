#!/bin/bash
# templateInit.sh — First-run template initialization script.
#
# Fired automatically by .devcontainer/devcontainer.json onCreateCommand.
# Detects whether this is a fresh template clone and, if so, auto-detects
# project details from the git remote and renames all references throughout
# the repo.
#
# Safe to run multiple times — exits immediately if already initialized.

set -e

TEMPLATE_USER="AI-Vectoring"
TEMPLATE_NAME="cluar5"
TEMPLATE_REPO="https://github.com/AI-Vectoring/cluar5.git"

# ── Check if already initialized ────────────────────────────────────────────
if ! grep -q "GITHUB_USER=${TEMPLATE_USER}" PROJECT.conf 2>/dev/null; then
    echo "Project already initialized. Nothing to rename."
    exit 0
fi

# ── Auto-detect from git remote ──────────────────────────────────────────────
REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)

if [ -z "$REMOTE_URL" ]; then
    echo "Error: no git remote 'origin' found. Cannot auto-detect project details."
    exit 1
fi

PROJECT_NAME=$(basename "$REMOTE_URL" .git)
GITHUB_USER=$(echo "$REMOTE_URL" | sed 's|.*[:/]\([^/]*\)/[^/]*\.git|\1|')

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║       cluar5 — First Run Setup               ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Detected from git remote:"
echo "  Project : ${PROJECT_NAME}"
echo "  User    : ${GITHUB_USER}"
echo ""

REPO_URL="git@github.com:${GITHUB_USER}/${PROJECT_NAME}.git"

echo "Initializing: ${TEMPLATE_NAME} → ${PROJECT_NAME}"
echo "Repository:   ${REPO_URL}"
echo ""

# ── Switch remote to SSH ─────────────────────────────────────────────────────
git remote set-url origin "${REPO_URL}"

# ── Update PROJECT.conf ───────────────────────────────────────────────────────
sed -i \
    -e "s|^PROJECT_NAME=.*|PROJECT_NAME=${PROJECT_NAME}|" \
    -e "s|^GITHUB_USER=.*|GITHUB_USER=${GITHUB_USER}|" \
    -e "s|^REPO_URL=.*|REPO_URL=${REPO_URL}|" \
    PROJECT.conf

# ── Rename all references in known text files ─────────────────────────────────
# Targets only committed file types — avoids binary files and .git directory.
find . -not -path './.git/*' -type f \( \
    -name "*.c"        -o \
    -name "*.h"        -o \
    -name "*.scm"      -o \
    -name "*.lua"      -o \
    -name "*.md"       -o \
    -name "*.sh"       -o \
    -name "*.json"     -o \
    -name "*.conf"     -o \
    -name "Dockerfile*" -o \
    -name "Makefile"   -o \
    -name "VERSIONS"   -o \
    -name "CONTRIBUTING" \
\) | while read -r file; do
    sed -i \
        -e "s|${TEMPLATE_USER}|${GITHUB_USER}|g" \
        -e "s|${TEMPLATE_NAME}|${PROJECT_NAME}|g" \
        -e "s|${TEMPLATE_REPO}|${REPO_URL}|g" \
        "$file"
done

# ── Local volume preference ───────────────────────────────────────────────────
cat <<EOF

Containerized-only vs Local volume storage

Because cluar5 requires several environments, we like to enclose it
completely in a container. This keeps your system clean and secure.
When you are done working, it all goes away with the container. This
means no local copy of any files, which live inside the container ONLY.
If you stop the container, the files are there for you next time. If you
remove the container, the files are gone forever. Because we use a
Github-heavy process, even if you lost the container, your files should
be in GitHub, provided you commit after every session.

- Stop the container   → files are still there next time
- Remove the container → files are gone forever
- Commit frequently, commit after every session.

All that said, this is a purist way of thinking and might not be practical for every
user, hence we can now enable the use of a local volume instead, providing
you a local copy that can be restored even if the container was eliminated.
This means triple redundancy: GitHub, container, local.

EOF
read -rp "Do you want to enable a local volume? (y/N) " LOCAL_VOLUME
echo ""

if [[ "${LOCAL_VOLUME}" =~ ^[Yy]$ ]]; then
    LOCAL_VOLUME_ENABLED=true
else
    LOCAL_VOLUME_ENABLED=false
fi

# ── Update PROJECT.conf with volume preference ────────────────────────────────
if grep -q "^LOCAL_VOLUME=" PROJECT.conf; then
    sed -i "s|^LOCAL_VOLUME=.*|LOCAL_VOLUME=${LOCAL_VOLUME_ENABLED}|" PROJECT.conf
else
    echo "LOCAL_VOLUME=${LOCAL_VOLUME_ENABLED}" >> PROJECT.conf
fi

# ── Configure devcontainer based on volume preference ────────────────────────
if [ "${LOCAL_VOLUME_ENABLED}" = "true" ]; then
    # Add workspaceMount so VS Code binds the local folder into the container
    sed -i '/"workspaceFolder"/a\    "workspaceMount": "source=${localWorkspaceFolder},target=/app,type=bind,consistency=cached",' \
        .devcontainer/devcontainer.json
fi

echo ""
echo "Done. Rename complete."
echo "  Name:       ${PROJECT_NAME}"
echo "  Repository: ${REPO_URL}"
echo ""
