#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 /path/to/release-metadata.json https://github.com/<user>/<repo>/releases/download/<tag>" >&2
  exit 1
fi

META_PATH="$1"
RELEASE_BASE_URL="$2"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$ROOT_DIR/build/release"
APPCAST_PATH="$OUT_DIR/appcast.xml"

if [[ ! -f "$META_PATH" ]]; then
  echo "Missing metadata file: $META_PATH" >&2
  exit 1
fi

SPARKLE_BIN_DIR="${SPARKLE_BIN_DIR:-$ROOT_DIR/.build/checkouts/Sparkle/bin}"
SPARKLE_PRIVATE_KEY_FILE="${SPARKLE_PRIVATE_KEY_FILE:-}"
SPARKLE_KEYCHAIN_ACCOUNT="${SPARKLE_KEYCHAIN_ACCOUNT:-ed25519}"
GENERATE_APPCAST_TOOL="${GENERATE_APPCAST_TOOL:-$SPARKLE_BIN_DIR/generate_appcast}"
SIGN_UPDATE_TOOL="${SIGN_UPDATE_TOOL:-$SPARKLE_BIN_DIR/sign_update}"

VERSION="$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$META_PATH")"
DMG_NAME="$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["sparkle_artifact"])' "$META_PATH")"
DMG_PATH="$OUT_DIR/$DMG_NAME"
PUB_DATE="$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S %z")"
ENCLOSURE_URL="${RELEASE_BASE_URL}/${DMG_NAME}"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Missing DMG: $DMG_PATH" >&2
  exit 1
fi

if [[ -x "$GENERATE_APPCAST_TOOL" ]]; then
  TMP_DIR="$(mktemp -d)"
  cp "$DMG_PATH" "$TMP_DIR/"
  GENERATE_APPCAST_OK=0
  if [[ -n "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
    if "$GENERATE_APPCAST_TOOL" "$TMP_DIR" --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" --download-url-prefix "${RELEASE_BASE_URL}/"; then
      GENERATE_APPCAST_OK=1
    fi
  else
    if "$GENERATE_APPCAST_TOOL" "$TMP_DIR" --account "$SPARKLE_KEYCHAIN_ACCOUNT" --download-url-prefix "${RELEASE_BASE_URL}/"; then
      GENERATE_APPCAST_OK=1
    fi
  fi

  if [[ $GENERATE_APPCAST_OK -eq 1 ]]; then
    cp "$TMP_DIR/appcast.xml" "$APPCAST_PATH"
    if rg -q "sparkle:edSignature=" "$APPCAST_PATH"; then
      rm -rf "$TMP_DIR"
      echo "$APPCAST_PATH"
      exit 0
    fi
    echo "generate_appcast output missing sparkle:edSignature; falling back to manual appcast generation." >&2
  fi

  rm -rf "$TMP_DIR"
  echo "generate_appcast failed; falling back to manual appcast generation." >&2
fi

{
  if [[ ! -x "$SIGN_UPDATE_TOOL" ]]; then
    echo "Neither generate_appcast nor sign_update tool found in $SPARKLE_BIN_DIR" >&2
    exit 1
  fi
  SIGNATURE="$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("sparkle_signature",""))' "$META_PATH")"
  if [[ -z "$SIGNATURE" || "$SIGNATURE" == "null" ]]; then
    if [[ -n "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
      SIGNATURE="$("$SIGN_UPDATE_TOOL" --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" -p "$DMG_PATH" 2>/dev/null)"
    else
      SIGNATURE="$("$SIGN_UPDATE_TOOL" --account "$SPARKLE_KEYCHAIN_ACCOUNT" -p "$DMG_PATH" 2>/dev/null)"
    fi
  fi
  LENGTH="$(stat -f%z "$DMG_PATH")"
  cat > "$APPCAST_PATH" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>ModelMeter Updates</title>
    <link>https://alirezamohammadpoor.github.io/ModelMeter/appcast.xml</link>
    <description>Latest releases of ModelMeter</description>
    <language>en</language>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <pubDate>${PUB_DATE}</pubDate>
      <enclosure url="${ENCLOSURE_URL}" sparkle:version="${VERSION}" sparkle:shortVersionString="${VERSION}" length="${LENGTH}" type="application/octet-stream" sparkle:edSignature="${SIGNATURE}" />
    </item>
  </channel>
</rss>
XML
}

echo "$APPCAST_PATH"
