#!/bin/sh
# Local CI: package unit tests, then a full app build from project.yml.
set -eu
cd "$(dirname "$0")/.."
swift test --package-path Packages/MickeyKit
xcodegen generate --quiet
xcodebuild -project Mickey.xcodeproj -scheme Mickey -configuration Debug -derivedDataPath build/DerivedData build -quiet
echo "CI OK: build/DerivedData/Build/Products/Debug/Mickey.app"
