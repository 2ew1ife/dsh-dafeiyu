#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
# A cloud-synced workspace can add Finder metadata to generated bundles.  Let
# local builders stage the app in a normal temporary directory while keeping
# the package default unchanged.
APP="${DSH_DAFEIYU_DARWIN_APP:-$ROOT/runtime/bin/darwin/dsh-dafeiyu-helper.app}"
BIN="$APP/Contents/MacOS/dsh-dafeiyu-helper"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

rm -rf "$APP"
mkdir -p "$(dirname "$BIN")" "$APP/Contents/Resources"
cp "$DIR/Info.plist" "$APP/Contents/Info.plist"
cp -R "$ROOT/assets" "$APP/Contents/Resources/assets"
PACKAGE_VERSION="$(node -p "require('$ROOT/package.json').version")"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $PACKAGE_VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $PACKAGE_VERSION" "$APP/Contents/Info.plist"

SOURCES=(
  "$DIR/Sources/AnimationModel.swift" \
  "$DIR/Sources/CustomSkinMotion.swift" \
  "$DIR/Sources/LayoutStore.swift" \
  "$DIR/Sources/PetGeometry.swift" \
  "$DIR/Sources/Permissions.swift" \
  "$DIR/Sources/PetController.swift" \
  "$DIR/Sources/PetView.swift" \
  "$DIR/Sources/main.swift" \
)
FRAMEWORKS=(
  -framework AppKit \
  -framework CoreImage \
  -framework UserNotifications \
  -framework ApplicationServices \
  -framework QuartzCore \
)

echo "building arm64 slice (macOS 12+)..."
swiftc -O -swift-version 5 -target arm64-apple-macosx12.0 \
  "${SOURCES[@]}" "${FRAMEWORKS[@]}" -o "$WORK/helper-arm64"

echo "building x86_64 slice (macOS 12+)..."
swiftc -O -swift-version 5 -target x86_64-apple-macosx12.0 \
  "${SOURCES[@]}" "${FRAMEWORKS[@]}" -o "$WORK/helper-x86_64"

lipo -create "$WORK/helper-arm64" "$WORK/helper-x86_64" -output "$BIN"
chmod 0755 "$BIN"
# Copying an app bundle on macOS can preserve Finder/resource-fork metadata.
# Ad-hoc signing rejects those attributes, so clear them before signing the
# generated artifact (not the source assets).
xattr -cr "$APP"
codesign --force --deep --sign - --timestamp=none "$APP"
lipo "$BIN" -verify_arch arm64 x86_64
plutil -lint "$APP/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "built universal macOS helper (arm64 + x86_64, macOS 12+): $APP"
