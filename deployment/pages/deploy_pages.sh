#!/bin/sh
# Publishes one release's web build to GitHub Pages:
#   https://jason0805-tech.github.io/Adventure-game/
# Usage: deploy_pages.sh "<release folder>/web-share" "<version label>"
# The gh-pages branch always holds exactly ONE build (the newest), as a single
# fresh commit of plain files (no Git LFS: Pages cannot serve LFS objects).
# The old gh-pages commit is replaced, so repository history does not grow.
set -eu
SRC="$1"
VERSION="$2"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REMOTE="$(git -C "$REPO_ROOT" remote get-url origin)"
[ -f "$SRC/index.html" ] || { echo "Missing $SRC/index.html" >&2; exit 1; }
[ -f "$SRC/payload.json" ] || { echo "Missing $SRC/payload.json" >&2; exit 1; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/forest-pages.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
cp -R "$SRC/." "$WORK/"
touch "$WORK/.nojekyll"   # serve files as-is, no Jekyll processing
printf '%s\n' "$VERSION" > "$WORK/VERSION.txt"
git -C "$WORK" init -q -b gh-pages
git -C "$WORK" config user.name "$(git -C "$REPO_ROOT" config user.name)"
git -C "$WORK" config user.email "$(git -C "$REPO_ROOT" config user.email)"
# Same GitHub login as the main repository (gh credential helper).
git -C "$WORK" config credential.https://github.com.helper ""
git -C "$WORK" config --add credential.https://github.com.helper "!$HOME/.local/bin/gh auth git-credential"
git -C "$WORK" config http.version HTTP/1.1
git -C "$WORK" config http.postBuffer 524288000
git -C "$WORK" add -A
git -C "$WORK" commit -q -m "Play in browser: Forest Wanderer $VERSION"
git -C "$WORK" push --force "$REMOTE" gh-pages:gh-pages
echo "Published $VERSION to gh-pages"
