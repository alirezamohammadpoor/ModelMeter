#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/ModelMeter.app" >&2
  exit 1
fi

APP_PATH="$1"
IDENTITY="${DEVELOPER_ID_APP:-}"

if [[ -z "$IDENTITY" ]]; then
  echo "Set DEVELOPER_ID_APP (Developer ID Application identity)" >&2
  exit 1
fi

PUBLIC_ED_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
if [[ -z "$PUBLIC_ED_KEY" || "$PUBLIC_ED_KEY" == "REPLACE_WITH_SPARKLE_PUBLIC_ED25519_KEY" ]]; then
  echo "SUPublicEDKey is missing or placeholder in $APP_PATH/Contents/Info.plist" >&2
  exit 1
fi

if [[ -d "$APP_PATH/Contents/Frameworks/Sparkle.framework" ]]; then
  codesign --force --options runtime --timestamp \
    --sign "$IDENTITY" \
    "$APP_PATH/Contents/Frameworks/Sparkle.framework"
fi

codesign --force --deep --options runtime --timestamp \
  --sign "$IDENTITY" \
  "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose "$APP_PATH"
