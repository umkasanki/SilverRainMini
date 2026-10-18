#!/bin/sh
# Renders the app icon from the station's logo and fills AppIcon.appiconset with its sizes.
# Run from anywhere: tools/build-icon.sh
set -e
cd "$(dirname "$0")"
SET=../Resources/Assets.xcassets/AppIcon.appiconset
swiftc -O make-icon.swift -o make-icon
./make-icon ../Resources/Assets.xcassets/StationLogo.imageset/StationLogo.svg icon_1024.png
for s in 16 32 64 128 256 512 1024; do
    sips -z $s $s icon_1024.png --out "$SET/AppIcon$s.png" >/dev/null
done
rm -f make-icon icon_1024.png
