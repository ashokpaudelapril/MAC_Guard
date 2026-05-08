#!/usr/bin/env bash
# build-release.sh — Build, sign, and notarize MacGuard.app
#
# PREREQUISITES (one-time setup):
#   1. Apple Developer ID Application certificate installed in your keychain.
#      Download from https://developer.apple.com/account > Certificates.
#
#   2. Store your Apple ID notarization credentials in the keychain so this
#      script never touches a password directly:
#
#        xcrun notarytool store-credentials "macguard-notarize" \
#          --apple-id "you@example.com" \
#          --team-id  "ABCDE12345" \
#          --password "xxxx-xxxx-xxxx-xxxx"   # app-specific password from appleid.apple.com
#
#   3. Install Xcode command-line tools:  xcode-select --install
#
# USAGE:
#   ./scripts/build-release.sh                  # uses defaults below
#   DEVELOPER_ID="Developer ID Application: Jane Doe (TEAMID)" \
#   APP_VERSION="1.1.0" ./scripts/build-release.sh
#
# OUTPUT:
#   dist/MacGuard.app        — signed + notarized + stapled app bundle
#   dist/MacGuard.zip        — submission zip (kept for audit; safe to delete)

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
# DEVELOPER_ID: your certificate CN from  security find-identity -v -p codesigning
DEVELOPER_ID="${DEVELOPER_ID:-"Developer ID Application: Ashok Paudel (TEAMID)"}"
NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-"macguard-notarize"}"   # keychain profile name
APP_VERSION="${APP_VERSION:-"1.0.0"}"
BUILD_NUMBER="${BUILD_NUMBER:-"1"}"
BUNDLE_ID="com.ashokpaudel.MacGuard"
# ──────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/MacGuard.app"
CONTENTS="$APP/Contents"
RELEASE_BIN="$ROOT/.build/apple/Products/Release/MacGuard"

echo "▶ MacGuard release build  (version $APP_VERSION, build $BUILD_NUMBER)"
echo "  Certificate : $DEVELOPER_ID"
echo "  Bundle ID   : $BUNDLE_ID"
echo ""

# ── Step 1: Compile universal release binary ──────────────────────────────────
echo "── 1/7  Compiling (arm64 + x86_64 universal) …"
# xcodebuild is required for universal SPM builds (swift build only targets the
# host arch). If you only need arm64, replace with:
#   swift build -c release
xcodebuild \
  -scheme MacGuard \
  -destination "generic/platform=macOS" \
  -configuration Release \
  -derivedDataPath "$ROOT/.build" \
  ONLY_ACTIVE_ARCH=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=NO \
  2>&1 | grep -E "^(error:|warning:|Build succeeded|** BUILD)"

# Fallback: if xcodebuild fails because no .xcodeproj exists, fall back to swift build
if [ ! -f "$RELEASE_BIN" ]; then
  echo "  (xcodebuild unavailable — falling back to swift build native arch)"
  swift build -c release --package-path "$ROOT"
  RELEASE_BIN="$ROOT/.build/release/MacGuard"
fi

echo "  Binary : $RELEASE_BIN"

# ── Step 2: Assemble .app bundle ──────────────────────────────────────────────
echo "── 2/7  Assembling MacGuard.app …"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp "$RELEASE_BIN"         "$CONTENTS/MacOS/MacGuard"
cp "$ROOT/Info.plist"     "$CONTENTS/Info.plist"

# Stamp the version fields into the bundle's Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER"           "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID"           "$CONTENTS/Info.plist"

# PkgInfo is required by Gatekeeper's bundle validation
printf "APPL????" > "$CONTENTS/PkgInfo"

echo "  Bundle : $APP"

# ── Step 3: Code sign ─────────────────────────────────────────────────────────
echo "── 3/7  Code signing …"
# Sign the binary first, then the bundle (--deep signs nested frameworks/libs)
codesign \
  --force \
  --options runtime \
  --entitlements "$ROOT/MacGuard.entitlements" \
  --sign "$DEVELOPER_ID" \
  --timestamp \
  "$CONTENTS/MacOS/MacGuard"

codesign \
  --force --deep \
  --options runtime \
  --entitlements "$ROOT/MacGuard.entitlements" \
  --sign "$DEVELOPER_ID" \
  --timestamp \
  "$APP"

# ── Step 4: Verify signature ──────────────────────────────────────────────────
echo "── 4/7  Verifying signature …"
codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | tail -5
spctl --assess --type execute --verbose=2 "$APP" 2>&1 || {
  echo "  ⚠ spctl assessment failed — the app may not yet be notarized."
  echo "    This is expected before notarization; continuing."
}

# ── Step 5: Package for notarization ─────────────────────────────────────────
echo "── 5/7  Creating notarization zip …"
rm -f "$DIST/MacGuard.zip"
ditto -c -k --keepParent "$APP" "$DIST/MacGuard.zip"
echo "  Zip : $DIST/MacGuard.zip  ($(du -sh "$DIST/MacGuard.zip" | cut -f1))"

# ── Step 6: Submit to Apple Notary Service ────────────────────────────────────
echo "── 6/7  Submitting to Apple Notary Service (this may take a few minutes) …"
xcrun notarytool submit "$DIST/MacGuard.zip" \
  --keychain-profile "$NOTARIZE_PROFILE" \
  --wait \
  --timeout 300

# ── Step 7: Staple the notarization ticket ────────────────────────────────────
echo "── 7/7  Stapling notarization ticket …"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "✅  MacGuard $APP_VERSION ($BUILD_NUMBER) is ready."
echo "    App : $APP"
echo "    Zip : $DIST/MacGuard.zip"
echo ""
echo "    Distribute: drag MacGuard.app to a DMG or zip it for download."
echo "    Users on macOS 13+ can drop it in /Applications and launch normally."
