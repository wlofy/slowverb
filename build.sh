#!/bin/sh
# Builds build/Slowverb.app (universal) with just the Command Line Tools — no Xcode project needed.
set -e
cd "$(dirname "$0")"
APP=build/Slowverb.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -parse-as-library -target "$arch-apple-macos14.4" Slowverb.swift Ring.swift FrequencyShifter.swift Artwork.swift -o "build/Slowverb-$arch"
done
lipo -create build/Slowverb-arm64 build/Slowverb-x86_64 -output "$APP/Contents/MacOS/Slowverb"
rm build/Slowverb-arm64 build/Slowverb-x86_64
mkdir -p "$APP/Contents/Resources"
rm -rf build/AppIcon.iconset
"$APP/Contents/MacOS/Slowverb" --iconset build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP — run: open $APP"
