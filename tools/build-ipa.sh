#!/usr/bin/env bash
#
# Builds a Feather-ready unsigned IPA on macOS (no Apple team, no code signing).
# Feather / Esign / Sideloadly sign it on the device with your own certificate.
#
# Usage:   ./tools/build-ipa.sh [bundle-id]
# Example: ./tools/build-ipa.sh com.yourname.storage

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUNDLE_ID="${1:-com.example.storageinspector}"
APP_NAME="StorageInspector"
DD="$ROOT/build/dd"
OUT="$ROOT/build/ipa"

echo "==> Project:   $ROOT"
echo "==> Bundle ID: $BUNDLE_ID"

xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DD" \
  -quiet \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  build

APP="$(find "$DD/Build/Products" -maxdepth 3 -name "$APP_NAME.app" -type d | head -n 1)"
if [ -z "$APP" ]; then
  echo "error: $APP_NAME.app not found in $DD/Build/Products" >&2
  exit 1
fi

echo "==> Loose icon files"
ICON_SRC="$(find "$ROOT" -maxdepth 8 -name 'AppIcon-1024.png' -path '*AppIcon.appiconset*' | head -n 1)"
if [ -n "$ICON_SRC" ]; then
  for pair in "AppIcon60x60@2x.png:120" "AppIcon60x60@3x.png:180" "AppIcon40x40@2x.png:80" "AppIcon40x40@3x.png:120" "AppIcon29x29@2x.png:58" "AppIcon29x29@3x.png:87"; do
    ICON_NAME="${pair%%:*}"
    ICON_SIZE="${pair##*:}"
    sips -z "$ICON_SIZE" "$ICON_SIZE" "$ICON_SRC" --out "$APP/$ICON_NAME" >/dev/null
  done
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIcons" "$APP/Info.plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleIcons dict" "$APP/Info.plist" >/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleIcons:CFBundlePrimaryIcon dict" "$APP/Info.plist" >/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles array" "$APP/Info.plist" >/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles:0 string AppIcon60x60" "$APP/Info.plist" >/dev/null || true
fi
echo "==> Alternate icons (Settings -> App Icon)"
VARIANT_DIR=""
for candidate in "$ROOT/StorageInspector/Resources/AppIconVariants" "$ROOT/Resources/AppIconVariants"; do
  if [ -d "$candidate" ]; then
    VARIANT_DIR="$candidate"
    break
  fi
done
if [ -n "$VARIANT_DIR" ]; then
  ALT_KEYS=""
  for entry in "Indigo:icon-indigo" "Graphite:icon-graphite" "Crimson:icon-crimson"; do
    KEY="${entry%%:*}"
    FILE="${entry##*:}"
    SRC="$VARIANT_DIR/$FILE.png"
    if [ ! -f "$SRC" ]; then
      echo "warning: $SRC is missing - the $KEY icon is skipped"
      continue
    fi
    sips -z 120 120 "$SRC" --out "$APP/Icon$KEY@2x.png" >/dev/null
    sips -z 180 180 "$SRC" --out "$APP/Icon$KEY@3x.png" >/dev/null
    ALT_KEYS="$ALT_KEYS $KEY"
  done
  if [ -n "$ALT_KEYS" ]; then
    /usr/libexec/PlistBuddy -c "Delete :CFBundleAlternateIcons" "$APP/Info.plist" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleAlternateIcons dict" "$APP/Info.plist"
    for KEY in $ALT_KEYS; do
      /usr/libexec/PlistBuddy -c "Add :CFBundleAlternateIcons:$KEY dict" "$APP/Info.plist"
      /usr/libexec/PlistBuddy -c "Add :CFBundleAlternateIcons:$KEY:CFBundleIconFiles array" "$APP/Info.plist"
      /usr/libexec/PlistBuddy -c "Add :CFBundleAlternateIcons:$KEY:CFBundleIconFiles:0 string Icon$KEY" "$APP/Info.plist"
    done
    echo "Alternate icons:$ALT_KEYS (orange stays the primary icon)"
  fi
fi
/usr/libexec/PlistBuddy -c "Add :LSRequiresIPhoneOS bool true" "$APP/Info.plist" >/dev/null 2>&1 || true

echo "==> Removing stale signatures"
rm -rf "$APP/_CodeSignature" "$APP/embedded.mobileprovision" "$APP/SC_Info"

echo "==> Packing Payload"
find "$APP" -name ".DS_Store" -delete 2>/dev/null || true
rm -rf "$OUT"
mkdir -p "$OUT/Payload"
cp -R "$APP" "$OUT/Payload/"
( cd "$OUT" && zip -q -r -y -9 "$APP_NAME-unsigned.ipa" Payload -x "*.DS_Store" )

echo
echo "OK: $OUT/$APP_NAME-unsigned.ipa"
echo "Bundle ID: $BUNDLE_ID"
echo "Install: Feather -> Certificates -> Import (.p12) -> Import Provisioning Profile"
echo "         -> '+' -> pick the .ipa -> Sign -> Install"
