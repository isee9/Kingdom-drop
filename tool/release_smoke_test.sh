#!/usr/bin/env bash
# Kingdom Drop — release smoke test (macOS / Linux).
#
# The bash twin of tool/release_smoke_test.ps1; see that file for why this
# exists. Short version: a release-only crash in a ContentProvider took the app
# down before Flutter started, and no amount of `flutter test`, `flutter
# analyze` or debug running could have caught it. Only launching a real release
# build on real hardware does.
#
#     ./tool/release_smoke_test.sh [device-id] [seconds]
#
# Run it before every upload to Google Play.
set -uo pipefail

APP_ID="com.yourcompany.kingdomdrop"   # keep in sync with build.gradle.kts
DEVICE="${1:-}"
WATCH="${2:-25}"

step() { printf '\n=== %s\n' "$1"; }
fail() { printf '\nSMOKE TEST FAILED: %s\n' "$1" >&2; exit 1; }

step "Finding a device"
if [ -z "$DEVICE" ]; then
  DEVICE=$(adb devices | awk '/\tdevice$/ {print $1; exit}')
fi
[ -n "$DEVICE" ] || fail "No device. Plug the phone in and enable USB debugging."
echo "Using $DEVICE"

step "Building the release APK"
# --release is the whole point: it is the only mode that runs R8.
flutter build apk --release || fail "the release build did not compile"

APK="build/app/outputs/flutter-apk/app-release.apk"
[ -f "$APK" ] || fail "expected the APK at $APK and it is not there"

step "Installing"
# Uninstall first, so this is a genuine cold start on a clean profile — the
# same situation a tester downloading from Play is in.
adb -s "$DEVICE" uninstall "$APP_ID" >/dev/null 2>&1 || true
adb -s "$DEVICE" install -r "$APK" || fail "install failed"

step "Launching and watching for ${WATCH}s"
adb -s "$DEVICE" logcat -c
adb -s "$DEVICE" shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep "$WATCH"

LOG=$(adb -s "$DEVICE" logcat -d)

step "Result"
if grep -qE "FATAL EXCEPTION|AndroidRuntime: Process: $APP_ID" <<<"$LOG"; then
  echo "--- crash ---"
  grep -A25 "AndroidRuntime" <<<"$LOG" | head -30
  fail "the app crashed on launch"
fi

# Alive, not merely un-crashed: a process that exited quietly would otherwise
# pass.
adb -s "$DEVICE" shell pidof "$APP_ID" >/dev/null 2>&1 \
  || fail "the app is not running — it started and then died"

# And far enough to draw. StageLog prints this the moment runApp is called.
grep -q "launch gate released" <<<"$LOG" || {
  echo "--- kd: lines ---"; grep "kd:" <<<"$LOG" || true
  fail "the app never reached runApp() — startup is blocked before the UI"
}

printf '\nPASSED — release APK installs, launches and reaches the UI.\n\n'
echo "Startup timeline:"
grep "kd:" <<<"$LOG" | sed 's/^/  /'
printf '\nNow play a round before uploading. This checks that it starts,\n'
printf 'not that it is fun.\n'
