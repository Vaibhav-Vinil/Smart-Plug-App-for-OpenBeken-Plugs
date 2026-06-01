$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$config = Get-Content (Join-Path $root "backend.config.json") | ConvertFrom-Json

$listening = Get-NetTCPConnection -LocalPort 1883 -State Listen -ErrorAction SilentlyContinue
if ($listening) {
    Write-Host "mosquitto version 2.0.22 running (port 1883 already in use)"
    exit 0
}

$exe = $config.mosquittoExe
$conf = Join-Path $root $config.mosquittoConfig
if (-not (Test-Path $exe)) {
    Write-Error "Mosquitto not found at: $exe"
}
Write-Host "Starting Mosquitto: $exe"
& $exe -c $conf -v
