#!/bin/bash
# Builds PeatsMac.app (menu bar app, no Dock icon). Run on a Mac with Xcode or the Swift toolchain.
set -euo pipefail
cd "$(dirname "$0")/.."

# Universal binary: runs on both Intel and Apple Silicon Macs.
FLAGS=(-c release --arch arm64 --arch x86_64)
swift build "${FLAGS[@]}"
BIN="$(swift build "${FLAGS[@]}" --show-bin-path)/PeatsMac"

APP="build/PeatsMac.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/PeatsMac"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# App icon: Resources/AppIcon.png (1024x1024) -> AppIcon.icns
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET" "$APP/Contents/Resources"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: enough for running locally. macOS asks for Bluetooth access on first launch.
codesign --force --sign - "$APP"
echo "Built $APP"
