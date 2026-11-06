#!/bin/sh
# Builds an isolated copy of Mickey and launches it.
#   scripts/run_dev.sh [app arguments, e.g. -AppleLanguages "(fr)"]
# The copy has its own bundle identifier (dev.local.mickey.dev), hence its own settings, permissions and
# sandbox container: it never reads or writes the data of the installed Mickey.
set -eu
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild -project Mickey.xcodeproj -scheme Mickey -configuration Debug -derivedDataPath build/DerivedDataDev \
  PRODUCT_BUNDLE_IDENTIFIER=dev.local.mickey.dev build -quiet
open -n build/DerivedDataDev/Build/Products/Debug/Mickey.app --args "$@"
