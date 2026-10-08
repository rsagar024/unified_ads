#!/usr/bin/env bash
# Verifies the CLAUDE.md opt-in requirement: an app that depends on a subset of
# adapters links only those networks' native SDKs.
#
# Usage: tool/verify_opt_in.sh android|ios
#   NETWORKS=admob,unity,inmobi   adapters the scratch app depends on (default)
#   META_BIDDING=admob|applovin|ironsource
#                                 also add that mediation platform's Meta bidding
#                                 adapter the way doc/setup/<network>.md says; the
#                                 Audience Network SDK must then be present
#   OPT_IN_WORKDIR=<dir>          where to create the scratch app (default: temp)
#   OPT_IN_LEAK=<network>         self-test: also depend on this adapter without
#                                 selecting it; the check must then fail
#
# It creates a scratch Flutter app OUTSIDE the workspace (as a consumer would),
# then checks the resolved native dependencies:
#   android: ./gradlew :app:dependencies --configuration releaseRuntimeClasspath
#   ios:     Podfile.lock after `pod install` (CocoaPods mode; macOS only)
# Every selected network's SDK must be present; every other network's SDK
# must be absent. On Android the legacy Google Mobile Ads SDK must never be
# resolved (the AdMob adapter uses GMA Next-Gen, and the two can't coexist).
# Exits non-zero on any violation.
set -euo pipefail

platform="${1:-}"
if [[ "$platform" != "android" && "$platform" != "ios" ]]; then
  echo "usage: $0 android|ios" >&2
  exit 2
fi

ALL_NETWORKS=(admob unity applovin ironsource facebook startapp inmobi)
IFS=',' read -r -a selected <<< "${NETWORKS:-admob,unity,inmobi}"
meta="${META_BIDDING:-}"

# Native SDK coordinates per network. Keep in sync with each adapter's
# android/build.gradle.kts and ios/*.podspec (pinned in SDK_STATUS.md).
android_sdk() {
  case "$1" in
    admob) echo 'com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:' ;;
    unity) echo 'com.unity3d.ads:unity-ads:' ;;
    applovin) echo 'com.applovin:applovin-sdk:' ;;
    ironsource) echo 'com.unity3d.ads-mediation:mediation-sdk:' ;;
    facebook) echo 'com.facebook.android:audience-network-sdk:' ;;
    startapp) echo 'com.startapp:inapp-sdk:' ;;
    inmobi) echo 'com.inmobi.monetization:inmobi-ads-kotlin:' ;;
  esac
}
ios_pod() {
  case "$1" in
    admob) echo 'Google-Mobile-Ads-SDK' ;;
    unity) echo 'UnityAds' ;;
    applovin) echo 'AppLovinSDK' ;;
    ironsource) echo 'IronSourceSDK' ;;
    facebook) echo 'FBAudienceNetwork' ;;
    startapp) echo 'StartAppSDK' ;;
    inmobi) echo 'InMobiSDK' ;;
  esac
}
LEGACY_GMA='com.google.android.gms:play-services-ads:'

# App-level opt-in lines for Meta bidding, exactly as documented in
# doc/setup/{admob,applovin,ironsource}.md.
meta_gradle() {
  case "$1" in
    admob)
      cat << 'EOF'
dependencies {
    implementation("com.google.ads.mediation:facebook:6.22.0.1")
}
// The Meta adapter depends on the legacy Google Mobile Ads SDK, which can't
// coexist with GMA Next-Gen (used by unified_ads_admob).
configurations.configureEach {
    exclude(group = "com.google.android.gms", module = "play-services-ads")
    exclude(group = "com.google.android.gms", module = "play-services-ads-lite")
}
EOF
      ;;
    applovin)
      cat << 'EOF'
dependencies {
    implementation("com.applovin.mediation:facebook-adapter:6.22.0.1")
}
EOF
      ;;
    ironsource)
      cat << 'EOF'
dependencies {
    implementation("com.unity3d.ads-mediation:facebook-adapter:5.5.0")
    // LevelPlay's Meta adapter doesn't bring the Audience Network SDK itself.
    implementation("com.facebook.android:audience-network-sdk:6.22.0")
}
EOF
      ;;
    *) echo "META_BIDDING must be admob, applovin or ironsource" >&2; exit 2 ;;
  esac
}
meta_pod() {
  case "$1" in
    admob) echo "pod 'GoogleMobileAdsMediationFacebook', '6.22.0.0'" ;;
    applovin) echo "pod 'AppLovinMediationFacebookAdapter', '6.22.0.4'" ;;
    ironsource) echo "pod 'IronSourceFacebookAdapter', '5.5.0.0'" ;;
  esac
}

for n in "${selected[@]}"; do
  if [[ -z "$(android_sdk "$n")" ]]; then
    echo "unknown network in NETWORKS: $n" >&2
    exit 2
  fi
done
if [[ -n "$meta" ]]; then
  meta_gradle "$meta" > /dev/null # validates the value
  # The mediation platform's own adapter is needed for its Meta adapter.
  found=false
  for n in "${selected[@]}"; do [[ "$n" == "$meta" ]] && found=true; done
  $found || selected+=("$meta")
fi

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Flutter on Windows needs C:/... paths; elsewhere this is a no-op.
native_path() { if command -v cygpath > /dev/null; then cygpath -m "$1"; else echo "$1"; fi; }

workdir="${OPT_IN_WORKDIR:-$(mktemp -d)}"
app="$workdir/opt_in_app"
rm -rf "$app"
echo "==> Creating scratch app in $app (networks: ${selected[*]}${meta:+; Meta bidding via $meta})"
flutter create --quiet --platforms android,ios --org dev.arovyx.optin "$app" > /dev/null

# Depend on the packages the way a consumer would (hosted-style constraints),
# and point them at this checkout with overrides (the packages may not be
# published yet).
deps="  unified_ads: ^1.0.0"
overrides="dependency_overrides:
  unified_ads:
    path: $(native_path "$repo/packages/unified_ads")
  unified_ads_platform_interface:
    path: $(native_path "$repo/packages/unified_ads_platform_interface")"
packages=("${selected[@]}")
[[ -n "${OPT_IN_LEAK:-}" ]] && packages+=("$OPT_IN_LEAK")
for n in "${packages[@]}"; do
  deps+=$'\n'"  unified_ads_$n: ^1.0.0"
  overrides+=$'\n'"  unified_ads_$n:
    path: $(native_path "$repo/packages/unified_ads_$n")"
done
awk -v deps="$deps" '{ print } /^dependencies:/ { print deps }' \
  "$app/pubspec.yaml" > "$app/pubspec.tmp" && mv "$app/pubspec.tmp" "$app/pubspec.yaml"
printf '%s\n' "$overrides" > "$app/pubspec_overrides.yaml"

# A network's SDK is expected when it was selected; Audience Network is also
# expected when Meta bidding was added through a mediation platform.
is_expected() {
  local n
  for n in "${selected[@]}"; do [[ "$n" == "$1" ]] && return 0; done
  [[ -n "$meta" && "$1" == "facebook" ]]
}

failures=0
check() { # check <listing file> <needle> <network>
  if is_expected "$3"; then
    if grep -qF -- "$2" "$1"; then
      echo "  ok      $3: $2 present"
    else
      echo "  FAIL    $3: $2 missing"
      failures=$((failures + 1))
    fi
  elif grep -qF -- "$2" "$1"; then
    echo "  FAIL    $3: $2 present but not selected"
    grep -F -- "$2" "$1" | head -3 | sed 's/^/          /'
    failures=$((failures + 1))
  else
    echo "  ok      $3: $2 absent"
  fi
}

cd "$app"
if [[ "$platform" == "android" ]]; then
  [[ -n "$meta" ]] && { echo; meta_gradle "$meta"; } >> android/app/build.gradle.kts
  echo "==> flutter build apk --config-only"
  flutter build apk --config-only > /dev/null
  listing="$app/release-runtime-classpath.txt"
  echo "==> gradlew :app:dependencies --configuration releaseRuntimeClasspath"
  (cd android && ./gradlew -q :app:dependencies --configuration releaseRuntimeClasspath) > "$listing"
  for n in "${ALL_NETWORKS[@]}"; do check "$listing" "$(android_sdk "$n")" "$n"; done
  if grep -qF -- "$LEGACY_GMA" "$listing"; then
    echo "  FAIL    legacy $LEGACY_GMA resolved (conflicts with GMA Next-Gen)"
    grep -F -- "$LEGACY_GMA" "$listing" | head -3 | sed 's/^/          /'
    failures=$((failures + 1))
  else
    echo "  ok      legacy $LEGACY_GMA absent"
  fi
else
  if [[ "$(uname)" != "Darwin" ]]; then
    echo "The iOS check needs macOS (CocoaPods)." >&2
    exit 2
  fi
  # CocoaPods mode, so Podfile.lock lists every native pod. (SwiftPM mode is
  # covered by the CI iOS build matrix.)
  printf '\nflutter:\n  config:\n    enable-swift-package-manager: false\n' >> pubspec.yaml
  # Audience Network (direct or through a Meta bidding adapter) needs iOS 15.
  ios_min=13.0
  is_expected facebook && ios_min=15.0
  echo "==> flutter build ios --config-only (iOS $ios_min)"
  flutter pub get > /dev/null
  flutter build ios --config-only --no-codesign > /dev/null || true
  sed -i.bak "s/^# platform :ios.*/platform :ios, '$ios_min'/" ios/Podfile
  if [[ -n "$meta" ]]; then
    pod_line="$(meta_pod "$meta")"
    sed -i.bak "s|^\( *\)flutter_install_all_ios_pods .*|&\n\1$pod_line|" ios/Podfile
    grep -qF "$pod_line" ios/Podfile
  fi
  (cd ios && pod install --repo-update > /dev/null)
  listing="$app/ios/Podfile.lock"
  for n in "${ALL_NETWORKS[@]}"; do check "$listing" "$(ios_pod "$n")" "$n"; done
fi

if ((failures > 0)); then
  echo "==> Opt-in verification FAILED ($failures problem(s)); listing: $listing"
  exit 1
fi
echo "==> Opt-in verification passed ($platform; ${selected[*]}${meta:+; Meta bidding via $meta})"
