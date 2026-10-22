#!/bin/zsh
# 카운트다운.app을 빌드해 ~/Applications에 설치하고 바탕화면에 바로가기를 만든다.
# 사용: ./build.sh
set -euo pipefail
cd "${0:A:h}"

APP_NAME="카운트다운"
BUILD=build
APP="$BUILD/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 1) 실행 파일
swiftc -O main.swift -o "$APP/Contents/MacOS/Countdown"

# 2) 아이콘
ICONSET="$BUILD/AppIcon.iconset"
mkdir -p "$ICONSET"
swift make-icon.swift "$BUILD/icon_1024.png" 1024
for s in 16 32 128 256 512; do
  sips -z $s $s "$BUILD/icon_1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$BUILD/icon_1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# 3) Info.plist
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>com.jaydenkang.countdown-overlay</string>
  <key>CFBundleExecutable</key><string>Countdown</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# 4) 설치 + 서명 + 바탕화면 바로가기(별칭)
# iCloud 동기화 폴더(바탕화면)에서는 확장 속성이 붙어 서명이 실패하므로 설치본에서 서명한다
mkdir -p "$INSTALL_DIR"
pkill -x Countdown || true   # 실행 중인 이전 버전 종료
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$APP" "$INSTALL_DIR/"
xattr -cr "$INSTALL_DIR/$APP_NAME.app"
codesign --force --sign - "$INSTALL_DIR/$APP_NAME.app"
# 한글 파일명은 NFC/NFD 표기가 섞일 수 있어, 정규화해서 기존 바로가기를 모두 지운다
python3 - "$APP_NAME" <<'PY'
import os, sys, unicodedata
name = unicodedata.normalize("NFC", sys.argv[1])
desk = os.path.expanduser("~/Desktop")
for f in os.listdir(desk):
    n = unicodedata.normalize("NFC", f)
    # "카운트다운", "카운트다운 2", "카운트다운 가상본" 같은 이전 별칭(파일)만 지운다
    if n.startswith(name) and os.path.isfile(os.path.join(desk, f)):
        os.remove(os.path.join(desk, f))
PY
# Finder는 별칭 이름에 "가상본" 같은 꼬리를 붙이므로 만든 뒤 이름을 정확히 맞춘다
osascript -e "tell application \"Finder\" to set name of (make alias file to (POSIX file \"$INSTALL_DIR/$APP_NAME.app\") at (path to desktop folder)) to \"$APP_NAME\"" >/dev/null \
  || ln -sf "$INSTALL_DIR/$APP_NAME.app" "$HOME/Desktop/$APP_NAME"

echo "설치: $INSTALL_DIR/$APP_NAME.app"
echo "바탕화면 바로가기: ~/Desktop/$APP_NAME"
