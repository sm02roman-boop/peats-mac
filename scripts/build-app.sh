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

# Ad-hoc signature: enough for running locally. macOS asks for Bluetooth access on first launch.
codesign --force --sign - "$APP"
echo "Built $APP"
