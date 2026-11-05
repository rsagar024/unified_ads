# Shared helpers for scripts that build a scratch consumer app outside the
# workspace (tool/verify_opt_in.sh, tool/ios_sim_smoke.sh). Source it; it
# defines functions only.

# Root of this checkout.
SCRATCH_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Flutter on Windows needs C:/... paths; elsewhere this is a no-op.
native_path() { if command -v cygpath > /dev/null; then cygpath -m "$1"; else echo "$1"; fi; }

# create_scratch_app <app dir> <network>...
#
# Creates a Flutter app at <app dir> (replacing it) that depends on unified_ads
# and the given adapters the way a consumer would (hosted-style constraints),
# pointed at this checkout with dependency overrides (the packages may not be
# published yet).
create_scratch_app() {
  local app="$1"
  shift
  rm -rf "$app"
  flutter create --quiet --platforms android,ios --org dev.arovyx.optin "$app" > /dev/null

  local deps="  unified_ads: ^1.1.0"
  local overrides="dependency_overrides:
  unified_ads:
    path: $(native_path "$SCRATCH_REPO/packages/unified_ads")
  unified_ads_platform_interface:
    path: $(native_path "$SCRATCH_REPO/packages/unified_ads_platform_interface")"
  local n
  for n in "$@"; do
    deps+=$'\n'"  unified_ads_$n: ^1.1.0"
    overrides+=$'\n'"  unified_ads_$n:
    path: $(native_path "$SCRATCH_REPO/packages/unified_ads_$n")"
  done
  # Multi-line values go through ENVIRON: BSD awk (macOS) rejects newlines in -v.
  DEPS="$deps" awk '{ print } /^dependencies:/ { print ENVIRON["DEPS"] }' \
    "$app/pubspec.yaml" > "$app/pubspec.tmp" && mv "$app/pubspec.tmp" "$app/pubspec.yaml"
  printf '%s\n' "$overrides" > "$app/pubspec_overrides.yaml"
}

# prepare_ios_project <app dir> <min iOS version>
#
# Sets the Runner project's deployment target (Swift Package Manager reads it
# from the Xcode project; there is no Podfile), then generates the Flutter
# plugin Swift package with `flutter build ios --config-only`. Audience Network
# needs iOS 15.
prepare_ios_project() {
  local app="$1" min="$2"
  (
    cd "$app"
    local pbxproj=ios/Runner.xcodeproj/project.pbxproj
    sed -i.bak -E "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = $min;/" "$pbxproj"
    rm -f "$pbxproj.bak"
    grep -q "IPHONEOS_DEPLOYMENT_TARGET = $min;" "$pbxproj"
    flutter pub get > /dev/null
    flutter build ios --config-only --no-codesign > /dev/null
  )
}
