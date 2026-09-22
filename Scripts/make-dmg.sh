#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="${DERIVED_DATA_PATH:-$ROOT/.derivedData}"
APP="$DERIVED/Build/Products/Release/Kuma.app"

cd "$ROOT"

xcodebuild \
  -scheme Kuma \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  build

# Helps Launch Services pick up AppIcon.icns after drag-install from DMG.
codesign --force --deep --sign - "$APP"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$ROOT/dist/Kuma-${VERSION}.dmg"
ICON_SRC="$APP/Contents/Resources/AppIcon.icns"

mkdir -p "$ROOT/dist"
STAGING="$(mktemp -d)"
ditto "$APP" "$STAGING/Kuma.app"
ln -s /Applications "$STAGING/Applications"

if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$STAGING/.VolumeIcon.icns"
  SetFile -a C "$STAGING" 2>/dev/null || true
fi

rm -f "$DMG"
hdiutil create -volname "Kuma" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"

hdiutil verify "$DMG"
ls -lh "$DMG"
echo "DMG ready: $DMG"
