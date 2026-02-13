#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/ModelMeter.app" >&2
  exit 1
fi

APP_PATH="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$ROOT_DIR/build/release"

mkdir -p "$OUT_DIR"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo dev)"
fi

ZIP_NAME="ModelMeter-v${VERSION}-macOS.zip"
ZIP_PATH="$OUT_DIR/$ZIP_NAME"
SHA_PATH="$ZIP_PATH.sha256"
DMG_NAME="ModelMeter-v${VERSION}-macOS.dmg"
DMG_PATH="$OUT_DIR/$DMG_NAME"
DMG_SHA_PATH="$DMG_PATH.sha256"
META_PATH="$OUT_DIR/release-metadata.json"

/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
if command -v create-dmg >/dev/null 2>&1; then
  create-dmg \
    --overwrite \
    --volname "ModelMeter ${VERSION}" \
    --window-pos 200 120 \
    --window-size 680 440 \
    --icon-size 120 \
    --icon "ModelMeter.app" 180 220 \
    --hide-extension "ModelMeter.app" \
    --app-drop-link 500 220 \
    "$DMG_PATH" \
    "$(dirname "$APP_PATH")"
else
  STAGING_DIR="$(mktemp -d)"
  cp -R "$APP_PATH" "$STAGING_DIR/ModelMeter.app"
  ln -s /Applications "$STAGING_DIR/Applications"
  hdiutil create -volname "ModelMeter ${VERSION}" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"
  rm -rf "$STAGING_DIR"
fi

shasum -a 256 "$ZIP_PATH" | awk '{print $1}' > "$SHA_PATH"
SHA_VALUE="$(cat "$SHA_PATH")"
shasum -a 256 "$DMG_PATH" | awk '{print $1}' > "$DMG_SHA_PATH"
DMG_SHA_VALUE="$(cat "$DMG_SHA_PATH")"

SPARKLE_BIN_DIR="${SPARKLE_BIN_DIR:-$ROOT_DIR/.build/checkouts/Sparkle/bin}"
SIGN_UPDATE_TOOL="${SIGN_UPDATE_TOOL:-$SPARKLE_BIN_DIR/sign_update}"
SPARKLE_PRIVATE_KEY_FILE="${SPARKLE_PRIVATE_KEY_FILE:-}"
SPARKLE_KEYCHAIN_ACCOUNT="${SPARKLE_KEYCHAIN_ACCOUNT:-ed25519}"
SPARKLE_SIGNATURE=""
if [[ -x "$SIGN_UPDATE_TOOL" ]]; then
  if [[ -n "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
    SPARKLE_SIGNATURE="$("$SIGN_UPDATE_TOOL" --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" -p "$DMG_PATH" 2>/dev/null)"
  else
    SPARKLE_SIGNATURE="$("$SIGN_UPDATE_TOOL" --account "$SPARKLE_KEYCHAIN_ACCOUNT" -p "$DMG_PATH" 2>/dev/null || true)"
  fi
fi

cat > "$META_PATH" <<JSON
{
  "version": "$VERSION",
  "artifact": "$ZIP_NAME",
  "sha256": "$SHA_VALUE",
  "sparkle_artifact": "$DMG_NAME",
  "sparkle_sha256": "$DMG_SHA_VALUE",
  "sparkle_signature": "$SPARKLE_SIGNATURE"
}
JSON

echo "$ZIP_PATH"
echo "$SHA_PATH"
echo "$DMG_PATH"
echo "$DMG_SHA_PATH"
echo "$META_PATH"
