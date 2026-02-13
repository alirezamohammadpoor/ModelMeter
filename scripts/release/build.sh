#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/release"
PRODUCT="ModelMeterApp"

mkdir -p "$BUILD_DIR"

swift build -c release --product "$PRODUCT" >&2

APP_TEMPLATE="$ROOT_DIR/ModelMeter.app"
APP_OUT="$BUILD_DIR/ModelMeter.app"
rm -rf "$APP_OUT"
mkdir -p "$APP_OUT/Contents/MacOS" "$APP_OUT/Contents/Resources"

EXECUTABLE_PATH="$(find "$ROOT_DIR/.build" -type f -path "*/release/$PRODUCT" | head -n 1)"
if [[ -z "${EXECUTABLE_PATH:-}" ]]; then
  echo "Could not locate built $PRODUCT binary" >&2
  exit 1
fi

cp "$EXECUTABLE_PATH" "$APP_OUT/Contents/MacOS/$PRODUCT"
chmod +x "$APP_OUT/Contents/MacOS/$PRODUCT"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_OUT/Contents/MacOS/$PRODUCT" 2>/dev/null || true

INFO_PLIST_SOURCE="$ROOT_DIR/Sources/ModelMeterApp/Info.plist"
if [[ ! -f "$INFO_PLIST_SOURCE" ]]; then
  echo "Missing Info.plist at $INFO_PLIST_SOURCE" >&2
  exit 1
fi
cp "$INFO_PLIST_SOURCE" "$APP_OUT/Contents/Info.plist"

RESOURCE_BUNDLE_PATH="$(find "$ROOT_DIR/.build" -type d -path "*/release/*ModelMeterApp.bundle" | head -n 1 || true)"
if [[ -n "$RESOURCE_BUNDLE_PATH" ]]; then
  cp -R "$RESOURCE_BUNDLE_PATH" "$APP_OUT/Contents/Resources/"
fi

SPARKLE_FRAMEWORK_PATH=""
for candidate in \
  "$ROOT_DIR/.build/arm64-apple-macosx/release/Sparkle.framework" \
  "$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
do
  if [[ -d "$candidate" ]]; then
    SPARKLE_FRAMEWORK_PATH="$candidate"
    break
  fi
done

if [[ -n "$SPARKLE_FRAMEWORK_PATH" ]]; then
  mkdir -p "$APP_OUT/Contents/Frameworks"
  cp -R "$SPARKLE_FRAMEWORK_PATH" "$APP_OUT/Contents/Frameworks/"
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $PRODUCT" "$APP_OUT/Contents/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleName ModelMeter" "$APP_OUT/Contents/Info.plist" >/dev/null

echo "$APP_OUT"
