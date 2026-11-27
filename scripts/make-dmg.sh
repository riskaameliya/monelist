#!/bin/bash
# Bungkus build/MoneList.app jadi DMG:  ./scripts/make-dmg.sh 1.0.0
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
APP="build/MoneList.app"
[ -d "$APP" ] || { echo "Jalankan ./build.sh dulu"; exit 1; }

STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "MoneList" -srcfolder "$STAGE" -ov -format UDZO "build/MoneList-$VERSION.dmg"
rm -rf "$STAGE"
echo "✔ build/MoneList-$VERSION.dmg"
