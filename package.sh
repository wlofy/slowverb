#!/bin/sh
# Builds build/Slowverb-<version>.dmg: the app plus an Applications shortcut to drag it onto.
set -e
cd "$(dirname "$0")"
./build.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
DMG="build/Slowverb-$VERSION.dmg"
rm -rf build/dmg "$DMG"
mkdir build/dmg
cp -R build/Slowverb.app build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -quiet -volname Slowverb -srcfolder build/dmg -format UDZO "$DMG"
rm -rf build/dmg
echo "Packaged $DMG"
