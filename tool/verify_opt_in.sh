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
#   ios:     Package.resolved after `xcodebuild -resolvePackageDependencies`
#            (Swift Package Manager; macOS only)
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
# android/build.gradle.kts and ios/<pkg>/Package.swift (pinned in SDK_STATUS.md).
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
# SwiftPM package identity (lowercased repository name) as it appears,
# quoted, in Package.resolved.
ios_spm() {
  case "$1" in
    admob) echo '"swift-package-manager-google-mobile-ads"' ;;
    unity) echo '"unity-ads-swift-package"' ;;
    applovin) echo '"applovin-max-swift-package"' ;;
    ironsource) echo '"levelplay-swift-package"' ;;
    facebook) echo '"fbaudiencenetwork"' ;;
    startapp) echo '"startappsdk-swiftpackage"' ;;
    inmobi) echo '"inmobisdk-swift-package"' ;;
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
# Meta bidding on iOS: the Swift package an app adds to its Runner target
# (Xcode > Add Package Dependencies), as "<url> <requirement> <product>".
# Requirement is exact:<version> or revision:<sha>. Google's Meta adapter tag
# 6.22.000 isn't valid semver, so it is pinned by that tag's commit.
meta_spm() {
  case "$1" in
    admob) echo "https://github.com/googleads/googleads-mobile-ios-mediation-meta.git revision:0a3d0597402162334fb5e11816ca612478180095 MetaAdapterTarget" ;;
    applovin) echo "https://github.com/AppLovin/AppLovin-MAX-Swift-Package-Meta.git exact:6220004.0.0 AppLovinMediationFacebookAdapter" ;;
    ironsource) echo "https://github.com/ironsource-mobile/LevelPlay-Facebook-Adapter-Swift-Package.git exact:5.5.0 FacebookAdapter" ;;
  esac
}

# add_spm_package <url> <requirement> <product>: adds a remote Swift package
# product to the Runner target with the xcodeproj gem (what Xcode's "Add
# Package Dependencies" does).
add_spm_package() {
  gem list -i xcodeproj > /dev/null || gem install --user-install --no-document xcodeproj > /dev/null
  PKG_URL="$1" PKG_REQ="$2" PKG_PRODUCT="$3" ruby -e '
    require "xcodeproj"
    kind, value = ENV["PKG_REQ"].split(":", 2)
    project = Xcodeproj::Project.open("ios/Runner.xcodeproj")
    target = project.targets.find { |t| t.name == "Runner" } or abort("no Runner target")
    pkg = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
    pkg.repositoryURL = ENV["PKG_URL"]
    pkg.requirement = kind == "revision" ?
      { "kind" => "revision", "revision" => value } :
      { "kind" => "exactVersion", "version" => value }
    project.root_object.package_references << pkg
    dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    dep.package = pkg
    dep.product_name = ENV["PKG_PRODUCT"]
    target.package_product_dependencies << dep
    file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    file.product_ref = dep
    target.frameworks_build_phase.files << file
    project.save
  '
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

# shellcheck source=lib/scratch_app.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/scratch_app.sh"

workdir="${OPT_IN_WORKDIR:-$(mktemp -d)}"
app="$workdir/opt_in_app"
echo "==> Creating scratch app in $app (networks: ${selected[*]}${meta:+; Meta bidding via $meta})"
packages=("${selected[@]}")
[[ -n "${OPT_IN_LEAK:-}" ]] && packages+=("$OPT_IN_LEAK")
create_scratch_app "$app" "${packages[@]}"

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
    echo "The iOS check needs macOS (Xcode)." >&2
    exit 2
  fi
  # Audience Network (direct or through a Meta bidding adapter) needs iOS 15.
  ios_min=13.0
  is_expected facebook && ios_min=15.0
  echo "==> flutter build ios --config-only (iOS $ios_min, Swift Package Manager)"
  flutter config --enable-swift-package-manager > /dev/null
  prepare_ios_project "$app" "$ios_min"
  if [[ -n "$meta" ]]; then
    read -r meta_url meta_req meta_product <<< "$(meta_spm "$meta")"
    echo "==> Adding $meta_product ($meta_url, $meta_req) to the Runner target"
    add_spm_package "$meta_url" "$meta_req" "$meta_product"
  fi
  echo "==> xcodebuild -resolvePackageDependencies"
  (cd ios && xcodebuild -resolvePackageDependencies -workspace Runner.xcworkspace -scheme Runner > /dev/null)
  listing="$app/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved"
  for n in "${ALL_NETWORKS[@]}"; do check "$listing" "$(ios_spm "$n")" "$n"; done
fi

if ((failures > 0)); then
  echo "==> Opt-in verification FAILED ($failures problem(s)); listing: $listing"
  exit 1
fi
echo "==> Opt-in verification passed ($platform; ${selected[*]}${meta:+; Meta bidding via $meta})"
