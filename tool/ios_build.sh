#!/usr/bin/env bash
# Builds the example app for iOS (no code signing) with Swift Package Manager,
# the only iOS dependency manager the plugins support (every package ships a
# Package.swift; there are no podspecs). The deployment target (15.0, for
# unified_ads_facebook) is set in example/ios/Runner.xcodeproj.
# macOS only. Used by CI; runnable locally.
set -euo pipefail

flutter config --enable-swift-package-manager

cd "$(dirname "${BASH_SOURCE[0]}")/../example"
flutter pub get

# Xcode stops at the first failing target by default, so a run would only
# surface one adapter's compile errors; report them all at once instead.
defaults write com.apple.dt.Xcode IDEBuildingContinueBuildingAfterErrors -bool YES

flutter build ios --debug --no-codesign

# The resolved vendor packages, for the CI log.
resolved=ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved
[[ -f "$resolved" ]] && grep -E '"(identity|version|revision)"' "$resolved" || true
