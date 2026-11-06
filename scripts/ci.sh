#!/bin/sh
# Local CI: package unit tests, localization check, release tool tests and release files check, then a full app build from project.yml.
set -eu
cd "$(dirname "$0")/.."
swift test --package-path Packages/MickeyKit
python3 -B scripts/l10n.py check
python3 -B -m unittest discover -s scripts/tests -q
python3 -B scripts/release.py check
xcodegen generate --quiet
xcodebuild -project Mickey.xcodeproj -scheme Mickey -configuration Debug -derivedDataPath build/DerivedData build -quiet
echo "CI OK: build/DerivedData/Build/Products/Debug/Mickey.app"
