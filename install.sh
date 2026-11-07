#!/bin/sh
# Builds Mickey, installs it into /Applications (replacing the previous copy) and relaunches it.
# Usage: ./install.sh [--no-launch] [--no-build]
# Re-signs the copy with scripts/sign_local.sh when it is there and its "Mickey Local Signing" identity exists,
# so macOS keeps the privacy permissions across updates.
set -eu
cd "$(dirname "$0")"

LAUNCH=1
BUILD=1
for arg in "$@"; do
  case "$arg" in
    --no-launch) LAUNCH=0 ;;
    --no-build) BUILD=0 ;;
    *) echo "usage: ./install.sh [--no-launch] [--no-build]" >&2; exit 2 ;;
  esac
done

BUILT=build/DerivedData/Build/Products/Release/Mickey.app
DEST=/Applications/Mickey.app

if [ "$BUILD" = 1 ]; then
  xcodegen generate --quiet
  xcodebuild -project Mickey.xcodeproj -scheme Mickey -configuration Release -derivedDataPath build/DerivedData build -quiet
fi
[ -d "$BUILT" ] || { echo "error: $BUILT not found, run without --no-build" >&2; exit 1; }

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BUILT/Contents/Info.plist")
if pgrep -x Mickey >/dev/null; then
  echo "Quitting running Mickey…"
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  for _ in $(seq 1 30); do pgrep -x Mickey >/dev/null || break; sleep 0.3; done
fi

ditto "$BUILT" "$DEST"
if [ -x scripts/sign_local.sh ] && security find-identity -v -p codesigning | grep -q '"Mickey Local Signing"'; then
  scripts/sign_local.sh "$DEST" --no-launch
else
  echo "note: no 'Mickey Local Signing' identity, keeping the build's own signature (permissions may reset on each install)"
fi
codesign --verify --deep --strict "$DEST"
echo "Installed $DEST"

if [ "$LAUNCH" = 1 ]; then open "$DEST"; fi
