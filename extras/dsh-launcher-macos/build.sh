#!/bin/bash
set -euo pipefail
SOURCE="$(cd "$(dirname "$0")" && pwd)"
APP="${1:-/private/tmp/DSH 启动器.app}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$SOURCE/Info.plist" "$APP/Contents/Info.plist"
export SDKROOT="${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/dsh-launcher-clang-cache}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
swiftc -O "$SOURCE/make-icon.swift" -framework AppKit -o "$WORK/make-icon"
"$WORK/make-icon" "$SOURCE/../kurumi-skin/images/idle.png" "$WORK/AppIcon.iconset"
iconutil -c icns "$WORK/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
swiftc -O -swift-version 5 -target arm64-apple-macosx12.0 "$SOURCE/main.swift" -framework AppKit -framework WebKit -o "$APP/Contents/MacOS/DSHLauncher"
xattr -cr "$APP"
codesign --force --deep --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
