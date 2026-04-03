$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$localProperties = Join-Path $projectRoot "android\\local.properties"

if (-not (Test-Path $localProperties)) {
  throw "android/local.properties not found."
}

$sdkLine = (Get-Content $localProperties | Where-Object { $_ -like "sdk.dir=*" } | Select-Object -First 1)
if (-not $sdkLine) {
  throw "sdk.dir is missing in android/local.properties."
}

$sdkDir = $sdkLine.Substring("sdk.dir=".Length).Replace("\\", "\")
$adb = Join-Path $sdkDir "platform-tools\\adb.exe"
$emulator = Join-Path $sdkDir "emulator\\emulator.exe"
$avdName = "Medium_Phone_API_36.1"
$serial = "emulator-5554"

if (-not (Test-Path $adb)) {
  throw "adb.exe not found at $adb"
}
if (-not (Test-Path $emulator)) {
  throw "emulator.exe not found at $emulator"
}

# Reset stale emulator instance if present.
$devices = & $adb devices
if ($devices -match $serial) {
  & $adb -s $serial emu kill | Out-Null
  Start-Sleep -Seconds 3
}

Start-Process -FilePath $emulator -ArgumentList @("-avd", $avdName, "-no-snapshot-load")

# Wait for device + full system boot.
$maxAttempts = 90
for ($i = 0; $i -lt $maxAttempts; $i++) {
  Start-Sleep -Seconds 2
  $devices = & $adb devices
  if ($devices -match "$serial\s+device") {
    $bootRaw = & $adb -s $serial shell getprop sys.boot_completed
    $boot = if ($bootRaw) { $bootRaw.Trim() } else { "" }
    if ($boot -eq "1") {
      & $adb -s $serial shell input keyevent 82 | Out-Null
      exit 0
    }
  }
}

throw "Emulator did not become ready in time."
