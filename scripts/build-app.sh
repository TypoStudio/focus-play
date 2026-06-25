#!/bin/bash
# FocusPlay 배포용 .app 번들 생성
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/FocusPlay.app"
VERSION="${1:-1.0.3}"
DMG="build/FocusPlay-${VERSION}.dmg"

# 빌드 번호: 빌드할 때마다 단조 증가(CFBundleVersion). 마케팅 버전(CFBundleShortVersionString)과 별개.
BUILD_FILE="scripts/.build-number"
BUILD=$(( $(cat "$BUILD_FILE" 2>/dev/null || echo 0) + 1 ))
echo "$BUILD" > "$BUILD_FILE"
echo "▶ 빌드 번호: $BUILD (버전 $VERSION)"

echo "▶ release 빌드..."
swift build -c release

echo "▶ 번들 구성: $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/FocusPlay" "$APP/Contents/MacOS/FocusPlay"

# 로컬라이제이션 리소스 번들 (.module) 포함
if [ -d ".build/release/FocusPlay_FocusPlay.bundle" ]; then
  cp -R ".build/release/FocusPlay_FocusPlay.bundle" "$APP/Contents/Resources/"
  # 앱이 시스템 언어로 실행되도록 최상위 Resources 에도 .lproj 를 둔다.
  # (최상위에 .lproj 가 없으면 macOS 가 앱을 영어 전용으로 인식한다)
  for d in "$APP/Contents/Resources/FocusPlay_FocusPlay.bundle"/*.lproj; do
    [ -d "$d" ] && cp -R "$d" "$APP/Contents/Resources/"
  done
fi

# 앱 아이콘 (.icns) 생성
if [ -f assets/icon-1024.png ]; then
  echo "▶ 아이콘 생성..."
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z "$s" "$s" assets/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z "$((s*2))" "$((s*2))" assets/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
fi

# Info.plist
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>FocusPlay</string>
    <key>CFBundleDisplayName</key><string>FocusPlay</string>
    <key>CFBundleDevelopmentRegion</key><string>ko</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>ko</string>
        <string>en</string>
        <string>ja</string>
        <string>zh-Hans</string>
        <string>zh-Hant</string>
        <string>es</string>
        <string>hi</string>
    </array>
    <key>CFBundleIdentifier</key><string>com.typostudio.focusplay</string>
    <key>CFBundleExecutable</key><string>FocusPlay</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>© 2026 TypoStudio</string>
</dict>
</plist>
PLIST

echo "▶ ad-hoc 서명..."
codesign --force --sign - "$APP"

echo "▶ DMG 생성: $DMG"
STAGE="$(mktemp -d)/FocusPlay"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "FocusPlay" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

echo "✅ 완료: $APP"
echo "✅ 완료: $DMG"
