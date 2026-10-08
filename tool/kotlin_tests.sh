#!/usr/bin/env bash
# Runs every adapter's Kotlin unit tests through the example app's Gradle
# build. The example must have been configured first (flutter build apk, or
# `flutter build apk --config-only`), which writes android/local.properties.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../example/android"
tasks=()
for n in admob applovin facebook inmobi ironsource startapp unity; do
  tasks+=(":unified_ads_$n:testDebugUnitTest")
done
./gradlew "${tasks[@]}"
