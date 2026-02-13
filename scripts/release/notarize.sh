#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/ModelMeter.app" >&2
  exit 1
fi

APP_PATH="$1"
PROFILE="${NOTARY_PROFILE:-}"

if [[ -z "$PROFILE" ]]; then
  echo "Set NOTARY_PROFILE for xcrun notarytool" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
ZIP_PATH="$TMP_DIR/ModelMeter-notary.zip"

/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo "$ZIP_PATH"
