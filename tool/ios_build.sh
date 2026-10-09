#!/usr/bin/env bash
# Builds the example app for iOS (no code signing) in one dependency mode:
#   spm                 Swift Package Manager where an adapter ships Package.swift,
#                       CocoaPods for the rest (Flutter's mixed mode)
#   cocoapods-dynamic   CocoaPods only, `use_frameworks!` (Flutter's default)
#   cocoapods-static    CocoaPods only, `use_frameworks! :linkage => :static`
# macOS only. Used by CI; runnable locally.
set -euo pipefail

mode="${1:-}"
case "$mode" in
  spm) flutter config --enable-swift-package-manager ;;
  cocoapods-dynamic | cocoapods-static) flutter config --no-enable-swift-package-manager ;;
  *)
    echo "usage: $0 spm|cocoapods-dynamic|cocoapods-static" >&2
    exit 2
    ;;
esac

cd "$(dirname "${BASH_SOURCE[0]}")/../example"
flutter pub get

# Generate ios/Podfile. pod install may fail on this first pass because the
# template leaves the platform unset (iOS 13 default), while unified_ads_facebook
# needs iOS 15, so the error is ignored.
flutter build ios --config-only --no-codesign || true
sed -i '' "s/^# platform :ios.*/platform :ios, '15.0'/" ios/Podfile
if [[ "$mode" == "cocoapods-static" ]]; then
  sed -i '' 's/^  use_frameworks!$/  use_frameworks! :linkage => :static/' ios/Podfile
  grep -q 'use_frameworks! :linkage => :static' ios/Podfile
fi
grep -n "platform :ios\|use_frameworks" ios/Podfile

# Xcode stops at the first failing target by default, so a run would only
# surface one adapter's compile errors; report them all at once instead.
defaults write com.apple.dt.Xcode IDEBuildingContinueBuildingAfterErrors -bool YES

flutter build ios --debug --no-codesign
