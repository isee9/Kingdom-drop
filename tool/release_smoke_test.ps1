# Kingdom Drop — release smoke test (Windows / PowerShell)
#
# Builds a *release* APK, installs it on a connected phone, launches it, and
# fails loudly if the app dies on startup.
#
# This exists because of a crash that no other check could have caught. It was
# release-only (R8 does not run in debug), it happened in a ContentProvider
# before Flutter started, and `flutter test`, `flutter analyze` and every debug
# run were all perfectly green while a signed build was unlaunchable. The only
# thing that catches that class of failure is starting a real release build on
# real hardware and watching what the system says.
#
# Usage, from the project root:
#
#     powershell -ExecutionPolicy Bypass -File tool\release_smoke_test.ps1
#
# Optional: -DeviceId <id>  to pick a phone when several are attached.
#           -Seconds <n>    how long to watch after launch (default 25).
#
# Run this before every upload to Google Play.

param(
    [string]$DeviceId = "",
    [int]$Seconds = 25
)

$ErrorActionPreference = "Stop"
$appId = "com.yourcompany.kingdomdrop"   # keep in sync with build.gradle.kts

function Step($message) {
    Write-Host ""
    Write-Host "=== $message" -ForegroundColor Cyan
}

function Fail($message) {
    Write-Host ""
    Write-Host "SMOKE TEST FAILED: $message" -ForegroundColor Red
    exit 1
}

# --------------------------------------------------------------- device
Step "Finding a device"
$devices = & adb devices | Select-String -Pattern "\tdevice$"
if (-not $devices) { Fail "No device. Plug the phone in and enable USB debugging." }

if ($DeviceId -eq "") {
    $DeviceId = ($devices[0] -split "\s+")[0]
}
Write-Host "Using $DeviceId"
$adb = @("-s", $DeviceId)

# ---------------------------------------------------------------- build
Step "Building the release APK"
# --release is the whole point: it is the only mode that runs R8, and R8 is
# what broke the app last time.
& flutter build apk --release
if ($LASTEXITCODE -ne 0) { Fail "the release build did not compile" }

$apk = "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apk)) { Fail "expected the APK at $apk and it is not there" }

# -------------------------------------------------------------- install
Step "Installing"
# Uninstall first so this is a genuine cold start on a clean profile, the same
# situation a tester downloading from Play is in.
& adb $adb uninstall $appId 2>$null | Out-Null
& adb $adb install -r $apk
if ($LASTEXITCODE -ne 0) { Fail "install failed" }

# --------------------------------------------------------------- launch
Step "Launching and watching for $Seconds seconds"
& adb $adb logcat -c
& adb $adb shell monkey -p $appId -c android.intent.category.LAUNCHER 1 | Out-Null

Start-Sleep -Seconds $Seconds

$log = & adb $adb logcat -d

# ------------------------------------------------------------- verdict
Step "Result"

$fatal = $log | Select-String -Pattern "FATAL EXCEPTION|AndroidRuntime: Process: $appId"
if ($fatal) {
    Write-Host "--- crash ---" -ForegroundColor Red
    $log | Select-String -Pattern "AndroidRuntime" -Context 0, 25 |
        Select-Object -First 1 | ForEach-Object { $_.Line; $_.Context.PostContext }
    Fail "the app crashed on launch"
}

# The app has to be alive, not merely un-crashed: a process that exited quietly
# would otherwise pass.
$pidLine = & adb $adb shell pidof $appId
if (-not $pidLine) { Fail "the app is not running — it started and then died" }

# And it has to have got far enough to draw. StageLog prints this the moment
# runApp is called, so its absence means startup stalled before the first frame.
$gate = $log | Select-String -Pattern "launch gate released"
if (-not $gate) {
    Write-Host "--- kd: lines ---" -ForegroundColor Yellow
    $log | Select-String -Pattern "kd:"
    Fail "the app never reached runApp() — startup is blocked before the UI"
}

Write-Host ""
Write-Host "PASSED — release APK installs, launches and reaches the UI." -ForegroundColor Green
Write-Host ""
Write-Host "Startup timeline:"
$log | Select-String -Pattern "kd:" | ForEach-Object { "  " + $_.Line }
Write-Host ""
Write-Host "Now play a round before uploading. This checks that it starts," -ForegroundColor Yellow
Write-Host "not that it is fun." -ForegroundColor Yellow
