#!/bin/bash
# Build MoneList.app tanpa Xcode penuh (cukup: xcode-select --install)
#   ./build.sh                              -> arsitektur Mac ini saja
#   ARCHS="arm64 x86_64" ./build.sh         -> universal (Apple Silicon + Intel)
#   VERSION=1.1.0 ./build.sh                -> set versi
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="MoneList"
SOURCE_DIR="Sources/TodoPomo"
VERSION="${VERSION:-1.0.0}"
ARCHS="${ARCHS:-$(uname -m)}"
BUILD="build"
APP="$BUILD/$APP_NAME.app"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "FFmpeg diperlukan untuk build. Instal dengan: brew install ffmpeg" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "▶ Compile ($ARCHS)"
BINS=()
for arch in $ARCHS; do
  out="$BUILD/$APP_NAME-$arch"
  swiftc -parse-as-library -O -target "$arch-apple-macos13.0" "$SOURCE_DIR"/*.swift -o "$out"
  BINS+=("$out")
done

if [ "${#BINS[@]}" -gt 1 ]; then
  lipo -create "${BINS[@]}" -output "$APP/Contents/MacOS/$APP_NAME"
else
  cp "${BINS[0]}" "$APP/Contents/MacOS/$APP_NAME"
fi
rm -f "${BINS[@]}"

cp Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"

ICONSET="$BUILD/$APP_NAME.iconset"
MASTER_ICON="$ICONSET/icon_512x512@2x.png"
LOGO_SOURCE="$SOURCE_DIR/Resources/PomoLogo.png"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
cp "$LOGO_SOURCE" "$SOURCE_DIR/Resources/PomoMascot.png" "$APP/Contents/Resources/"
# Gunakan CAF agar audio dapat diputar dengan NSSound di macOS 13.
ffmpeg -nostdin -loglevel error -y -i "$SOURCE_DIR/Resources/cat-meow.ogg" \
  -c:a pcm_s16le "$APP/Contents/Resources/cat-meow.caf"
swift scripts/create-app-icon.swift "$LOGO_SOURCE" "$MASTER_ICON"

make_icon_size() {
  local filename="$1"
  local size="$2"
  sips -z "$size" "$size" "$MASTER_ICON" --out "$ICONSET/$filename" >/dev/null
}

make_icon_size "icon_16x16.png" 16
make_icon_size "icon_16x16@2x.png" 32
make_icon_size "icon_32x32.png" 32
make_icon_size "icon_32x32@2x.png" 64
make_icon_size "icon_128x128.png" 128
make_icon_size "icon_128x128@2x.png" 256
make_icon_size "icon_256x256.png" 256
make_icon_size "icon_256x256@2x.png" 512
make_icon_size "icon_512x512.png" 512
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/PomoAppIcon.icns"
rm -rf "$ICONSET"

echo "▶ Sign (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "✔ Selesai: $APP"
