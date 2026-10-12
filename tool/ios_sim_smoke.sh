#!/usr/bin/env bash
# iOS simulator smoke test (macOS only; no code signing, no Apple account).
# Used by .github/workflows/ios.yml; runnable locally on a Mac.
#
# Usage: tool/ios_sim_smoke.sh all|<network>
#   all        the root example/ app (links every adapter)
#   <network>  a scratch consumer app that depends on ONLY that adapter
#              (admob unity applovin ironsource facebook startapp inmobi)
#
#   NETWORKS=a,b        networks the test exercises (default: all → every
#                       adapter except ironsource, which can't run alongside
#                       Unity Ads in one app and is covered by its own run;
#                       <network> → that network)
#   ARTIFACTS_DIR=<dir> screenshots, logs, Podfile.lock (default:
#                       artifacts/<target> in the checkout)
#   SMOKE_WORKDIR=<dir> where scratch apps are created (default: temp)
#   SMOKE_DEVICE=<name> simulator to use (default: "iPhone 16"; falls back
#                       to the first available iPhone)
#   LOAD_TIMEOUT_S=<s>  per-load timeout passed to the test (default 45)
#   DRIVE_TIMEOUT_S=<s> flutter drive --timeout for the test run (default 1200)
#   DRIVE_HARD_TIMEOUT_S=<s>
#                       kill flutter drive after this long, including a hang
#                       at launch (default 1800; keep it under the CI job
#                       timeout so artifacts are still collected)
#
# Steps: prepare the app (Info.plist keys, Podfile platform) → check it with
# tool/verify_ios_plist.dart → flutter build ios --simulator --no-codesign →
# boot a simulator → flutter drive integration_test/ad_smoke_test.dart, with
# a screenshot every 10 s and on exit.
set -euo pipefail

target="${1:-}"
ALL_NETWORKS=(admob unity applovin ironsource facebook startapp inmobi)
valid=false
for n in all "${ALL_NETWORKS[@]}"; do [[ "$target" == "$n" ]] && valid=true; done
if ! $valid; then
  echo "usage: $0 all|${ALL_NETWORKS[*]// /|}" >&2
  exit 2
fi
if [[ "$(uname)" != "Darwin" ]]; then
  echo "The iOS simulator smoke test needs macOS." >&2
  exit 2
fi

# shellcheck source=lib/scratch_app.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/scratch_app.sh"
repo="$SCRATCH_REPO"
art="${ARTIFACTS_DIR:-$repo/artifacts/$target}"
mkdir -p "$art"
art="$(cd "$art" && pwd)"
device_name="${SMOKE_DEVICE:-iPhone 16}"
load_timeout="${LOAD_TIMEOUT_S:-45}"
drive_timeout="${DRIVE_TIMEOUT_S:-1200}"
drive_hard_timeout="${DRIVE_HARD_TIMEOUT_S:-1800}"

if [[ "$target" == "all" ]]; then
  app="$repo/example"
  networks="${NETWORKS:-admob,unity,applovin,facebook,startapp,inmobi}"
  plist_networks="admob,unity,applovin,ironsource,facebook,startapp,inmobi"
  privacy=(--privacy "$app/ios/Runner/PrivacyInfo.xcprivacy")
  echo "==> Root example app (networks under test: $networks)"
  (cd "$app" && flutter pub get > /dev/null)
else
  networks="${NETWORKS:-$target}"
  plist_networks="$target"
  privacy=()
  workdir="${SMOKE_WORKDIR:-$(mktemp -d)}"
  app="$workdir/smoke_$target"
  echo "==> Scratch app with only unified_ads_$target in $app"
  create_scratch_app "$app" "$target"

  # Test-only dev dependencies + the smoke test and its driver.
  awk '{ print } /^dev_dependencies:/ {
      print "  flutter_driver:\n    sdk: flutter\n  integration_test:\n    sdk: flutter" }' \
    "$app/pubspec.yaml" > "$app/pubspec.tmp" && mv "$app/pubspec.tmp" "$app/pubspec.yaml"
  mkdir -p "$app/integration_test" "$app/test_driver"
  cp "$repo"/example/integration_test/{ad_smoke_test,smoke_ids,support}.dart "$app/integration_test/"
  cp "$repo/example/test_driver/integration_test.dart" "$app/test_driver/"

  # Info.plist entries the network needs (doc/ios_setup.md).
  plist="$app/ios/Runner/Info.plist"
  pb() { /usr/libexec/PlistBuddy -c "$1" "$plist"; }
  pb "Add :NSUserTrackingUsageDescription string 'This identifier will be used to deliver personalized ads to you.'"
  if [[ "$target" == "admob" ]]; then
    # Google's public sample App ID (doc/getting_ids.md).
    pb "Add :GADApplicationIdentifier string ca-app-pub-3940256099942544~1458002511"
  fi
  pb "Add :SKAdNetworkItems array"
  i=0
  while read -r id; do
    [[ -z "$id" ]] && continue
    pb "Add :SKAdNetworkItems:$i dict"
    pb "Add :SKAdNetworkItems:$i:SKAdNetworkIdentifier string $id"
    i=$((i + 1))
  done < <(cd "$repo" && dart run tool/verify_ios_plist.dart --list-skadnetwork-ids --networks "$target")

  ios_min=13.0
  [[ "$target" == "facebook" ]] && ios_min=15.0
  echo "==> Podfile platform iOS $ios_min"
  prepare_ios_podfile "$app" "$ios_min"
fi

echo "==> Checking Info.plist (networks: $plist_networks)"
(cd "$repo" && dart run tool/verify_ios_plist.dart --plist "$app/ios/Runner/Info.plist" \
  --networks "$plist_networks" ${privacy[@]+"${privacy[@]}"}) | tee "$art/plist_check.txt"

echo "==> flutter build ios --simulator --no-codesign"
set +e
(cd "$app" && flutter build ios --simulator --no-codesign) 2>&1 | tee "$art/build.log"
build_status=${PIPESTATUS[0]}
set -e
cp "$app/ios/Podfile.lock" "$art/" 2> /dev/null || true
cp "$app/ios/Podfile" "$art/" 2> /dev/null || true
if ((build_status != 0)); then
  echo "==> Build FAILED (exit $build_status); see $art/build.log"
  exit "$build_status"
fi
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
  "$app/build/ios/iphonesimulator/Runner.app/Info.plist" 2> /dev/null || true)"

# Pick a simulator: the requested name on the newest runtime that has it,
# else the first available iPhone on the newest runtime.
udid="$(xcrun simctl list devices available -j | DEVICE="$device_name" python3 -c '
import json, os, re, sys
devices = json.load(sys.stdin)["devices"]
def version(runtime):
    return [int(x) for x in re.findall(r"\d+", runtime.split("iOS")[-1])]
runtimes = sorted((r for r in devices if "iOS" in r), key=version, reverse=True)
want = os.environ["DEVICE"]
for match in (lambda d: d["name"] == want, lambda d: d["name"].startswith("iPhone")):
    for r in runtimes:
        for d in devices[r]:
            if match(d):
                print(d["udid"]); sys.exit(0)
sys.exit("no available iPhone simulator")
')"
echo "==> Simulator $udid ($(xcrun simctl list devices | grep "$udid" | sed 's/^ *//'))"
xcrun simctl boot "$udid" 2> /dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$udid" || true
xcrun simctl bootstatus "$udid" -b

shot() { xcrun simctl io "$udid" screenshot "$art/$1.png" > /dev/null 2>&1 || true; }
(
  n=0
  while true; do
    shot "$(printf 'shot-%03d' "$n")"
    n=$((n + 1))
    sleep 10
  done
) &
shooter=$!
finish() {
  kill "$shooter" 2> /dev/null || true
  shot final
  # flutter drive runs with --keep-app-running (see below), so stop the app
  # here; an app that is already gone is reported, not fatal.
  if [[ -n "$bundle_id" ]] &&
    ! xcrun simctl terminate "$udid" "$bundle_id" > /dev/null 2>&1; then
    echo "==> $bundle_id was not running at exit (possible crash; see device.log / *.ips)"
  fi
  # Native log of the app process, for crashes that never reach Dart.
  xcrun simctl spawn "$udid" log show --last 15m --style compact \
    --predicate 'process == "Runner"' > "$art/device.log" 2> /dev/null || true
  cp ~/Library/Logs/DiagnosticReports/Runner*.ips "$art/" 2> /dev/null || true
  # The test prints a summary block; keep it on its own for CI summaries.
  sed -n '/==== SMOKE SUMMARY ====/,/==== END SMOKE SUMMARY ====/p' "$art/drive.log" \
    > "$art/summary.txt" 2> /dev/null || true
}
trap finish EXIT

echo "==> flutter drive integration_test/ad_smoke_test.dart (networks: $networks)"
# --keep-app-running: without it flutter drive ends with `simctl terminate`,
# which exits 1 ("found nothing to terminate") when the app is already gone
# and turns a passing run into a failure. finish() stops the app instead.
# perl's alarm (inherited across exec) is the hard timeout; macOS has no
# `timeout` command.
set +e
(cd "$app" && perl -e 'alarm shift; exec @ARGV' "$drive_hard_timeout" \
  flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/ad_smoke_test.dart \
  -d "$udid" \
  --keep-app-running \
  --timeout "$drive_timeout" \
  --dart-define=NETWORKS="$networks" \
  --dart-define=LOAD_TIMEOUT_S="$load_timeout") 2>&1 | tee "$art/drive.log"
drive_status=${PIPESTATUS[0]}
set -e
if ((drive_status == 142)); then
  echo "==> flutter drive timed out after ${drive_hard_timeout}s (SIGALRM)"
fi
echo "==> flutter drive exited $drive_status; artifacts in $art"
exit "$drive_status"
