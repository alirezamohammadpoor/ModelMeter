#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/appcast.xml" >&2
  exit 1
fi

APPCAST_PATH="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PAGES_BRANCH="${PAGES_BRANCH:-gh-pages}"
TMP_DIR="$(mktemp -d)"

if [[ ! -f "$APPCAST_PATH" ]]; then
  echo "Missing appcast at $APPCAST_PATH" >&2
  exit 1
fi

git clone --depth 1 --branch "$PAGES_BRANCH" "file://$ROOT_DIR" "$TMP_DIR"
cp "$APPCAST_PATH" "$TMP_DIR/appcast.xml"

(
  cd "$TMP_DIR"
  git add appcast.xml
  if git diff --cached --quiet; then
    echo "No appcast changes to publish."
    exit 0
  fi
  git commit -m "Update Sparkle appcast"
  git push origin "$PAGES_BRANCH"
)

rm -rf "$TMP_DIR"
