#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="${1:-$(uname -m)}"
case "$ARCH" in
  arm64) ARCH_LABEL="Apple-Silicon" ;;
  x86_64) ARCH_LABEL="Intel" ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac
if [[ "$(uname -m)" != "$ARCH" ]]; then
  echo "Build $ARCH on a matching Mac or GitHub runner; cross-built PyInstaller helpers are unsafe." >&2
  exit 1
fi

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  else
    DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
  fi
fi
VERSION="${VERSION:-$(sed -n 's/^version = "\([^"]*\)"/\1/p' "$ROOT/pyproject.toml" | head -1)}"
BUILD_ROOT="$ROOT/build/macos-app-$ARCH"
APP="$BUILD_ROOT/HideMyEmail Generator.app"
ASSET_BASE="$ROOT/dist/HideMyEmail-Generator-macOS-$ARCH_LABEL"
ZIP="$ASSET_BASE.zip"
DMG="$ASSET_BASE.dmg"

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT/pyinstaller" "$ROOT/dist"

cd "$ROOT"
uv run --frozen --with pyinstaller pyinstaller \
  --noconfirm \
  --clean \
  --onefile \
  --name hidemyemail \
  --collect-data certifi \
  --distpath "$BUILD_ROOT/helper" \
  --workpath "$BUILD_ROOT/pyinstaller/work" \
  --specpath "$BUILD_ROOT/pyinstaller" \
  src/hidemyemail_generator/__main__.py

cd "$ROOT/macos"
DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild \
  -scheme HideMyEmailGenerator \
  -configuration Release \
  -destination "platform=macOS,arch=$ARCH" \
  -derivedDataPath "$BUILD_ROOT/xcode" \
  ARCHS="$ARCH" \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO \
  build

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD_ROOT/xcode/Build/Products/Release/HideMyEmailGenerator" \
  "$APP/Contents/MacOS/HideMyEmailGenerator"
cp "$BUILD_ROOT/helper/hidemyemail" "$APP/Contents/Resources/hidemyemail"
cp "$ROOT/macos/Info.plist" "$APP/Contents/Info.plist"
chmod 755 "$APP/Contents/MacOS/HideMyEmailGenerator" "$APP/Contents/Resources/hidemyemail"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"

for binary in \
  "$APP/Contents/MacOS/HideMyEmailGenerator" \
  "$APP/Contents/Resources/hidemyemail"; do
  if [[ "$(lipo -archs "$binary")" != "$ARCH" ]]; then
    echo "Expected a single $ARCH slice in $binary" >&2
    exit 1
  fi
done

rm -f "$ZIP" "$DMG"
COPYFILE_DISABLE=1 ditto -c -k --keepParent --norsrc --noextattr --noqtn --noacl "$APP" "$ZIP"
hdiutil create \
  -volname "HideMyEmail Generator" \
  -srcfolder "$APP" \
  -format UDZO \
  "$DMG"

echo "App: $APP"
echo "ZIP: $ZIP"
echo "DMG: $DMG"
