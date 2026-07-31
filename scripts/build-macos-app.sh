#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="${1:-$(uname -m)}"
case "$ARCH" in
  arm64)
    ARCH_LABEL="Apple-Silicon"
    DEFAULT_FEED_URL="https://github.com/rtunazzz/hidemyemail-generator/releases/latest/download/appcast-arm64.xml"
    ;;
  x86_64)
    ARCH_LABEL="Intel"
    DEFAULT_FEED_URL="https://github.com/rtunazzz/hidemyemail-generator/releases/latest/download/appcast-x86_64.xml"
    ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac
if [[ "$(uname -m)" != "$ARCH" ]]; then
  echo "Build $ARCH on a matching Mac or GitHub runner; cross-built PyInstaller helpers are unsafe." >&2
  exit 1
fi

DEVELOPER_DIR="$("$ROOT/scripts/xcode-developer-dir.sh")"
VERSION="${VERSION:-$(sed -n 's/^version = "\([^"]*\)"/\1/p' "$ROOT/pyproject.toml" | head -1)}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-$DEFAULT_FEED_URL}"
BUILD_ROOT="$ROOT/build/macos-app-$ARCH"
APP="$BUILD_ROOT/HideMyEmail Generator.app"
ASSET_BASE="$ROOT/dist/HideMyEmail-Generator-macOS-$ARCH_LABEL"
ZIP="$ASSET_BASE.zip"
DMG="$ASSET_BASE.dmg"

rm -rf "$BUILD_ROOT"
rm -f "$ZIP" "$DMG"
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

SPARKLE_FRAMEWORK="$BUILD_ROOT/xcode/Build/Products/Release/Sparkle.framework"
test -d "$SPARKLE_FRAMEWORK"

mkdir -p "$APP/Contents/Frameworks" "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD_ROOT/xcode/Build/Products/Release/HideMyEmailGenerator" \
  "$APP/Contents/MacOS/HideMyEmailGenerator"
cp "$BUILD_ROOT/helper/hidemyemail" "$APP/Contents/Resources/hidemyemail"
ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
cp "$ROOT/macos/Info.plist" "$APP/Contents/Info.plist"
DEVELOPER_DIR="$DEVELOPER_DIR" xcrun actool \
  --compile "$APP/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target 13.0 \
  --target-device mac \
  --app-icon HME-Gen-icon \
  --output-partial-info-plist "$BUILD_ROOT/icon-info.plist" \
  --warnings \
  --errors \
  --notices \
  --output-format human-readable-text \
  "$ROOT/HME-Gen-icon.icon"
test -f "$APP/Contents/Resources/Assets.car"
test -f "$APP/Contents/Resources/HME-Gen-icon.icns"
chmod 755 "$APP/Contents/MacOS/HideMyEmailGenerator" "$APP/Contents/Resources/hidemyemail"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :SUFeedURL $SPARKLE_FEED_URL" "$APP/Contents/Info.plist"

for binary in \
  "$APP/Contents/MacOS/HideMyEmailGenerator" \
  "$APP/Contents/Resources/hidemyemail"; do
  if [[ "$(lipo -archs "$binary")" != "$ARCH" ]]; then
    echo "Expected a single $ARCH slice in $binary" >&2
    exit 1
  fi
done

test -x "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
if ! otool -l "$APP/Contents/MacOS/HideMyEmailGenerator" \
  | grep -A2 LC_RPATH \
  | grep -Fq '@executable_path/../Frameworks'; then
  echo "The app executable cannot load its bundled Sparkle framework." >&2
  exit 1
fi

# Sparkle requires a structurally valid bundle signature. This identity-free
# signature carries no Apple team and leaves release trust to the EdDSA key.
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"

for artifact in \
  "$APP" \
  "$APP/Contents/MacOS/HideMyEmailGenerator" \
  "$APP/Contents/Resources/hidemyemail"; do
  if codesign -dvv "$artifact" 2>&1 | grep -Eq '^(TeamIdentifier=[A-Z0-9]|Authority=)'; then
    echo "Refusing to package an Apple-team-signed artifact: $artifact" >&2
    exit 1
  fi
done

COPYFILE_DISABLE=1 ditto -c -k --keepParent --norsrc --noextattr --noqtn --noacl "$APP" "$ZIP"
hdiutil create \
  -volname "HideMyEmail Generator" \
  -srcfolder "$APP" \
  -format UDZO \
  "$DMG"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp=none --sign "$CODESIGN_IDENTITY" \
    "$APP/Contents/Resources/hidemyemail"
  codesign --force --options runtime --timestamp=none --sign "$CODESIGN_IDENTITY" "$APP"
  codesign --verify --deep --strict "$APP"
fi

echo "App: $APP"
echo "ZIP: $ZIP"
echo "DMG: $DMG"
