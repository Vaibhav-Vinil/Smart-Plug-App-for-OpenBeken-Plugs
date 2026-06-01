$root = Split-Path -Parent $PSScriptRoot
$config = Get-Content (Join-Path $root "backend.config.json") | ConvertFrom-Json

$env:MQTT_TOPIC_PREFIX = $config.mqttTopicPrefix
$env:MQTT_BROKER = $config.mqttBroker

$deadline = (Get-Date).AddSeconds(45)
while ((Get-Date) -lt $deadline) {
    if (Get-NetTCPConnection -LocalPort 1883 -State Listen -ErrorAction SilentlyContinue) {
        break
    }
    Write-Host "Waiting for Mosquitto on port 1883..."
    Start-Sleep -Seconds 1
}

if (-not (Get-NetTCPConnection -LocalPort 1883 -State Listen -ErrorAction SilentlyContinue)) {
    Write-Error "Mosquitto is not listening on port 1883. Check the Mosquitto Broker terminal."
    exit 1
}

$script = Join-Path $root "mqtt_recorder.py"
Write-Host "--- Smart Plug History Recorder ---"
Write-Host "Broker: $env:MQTT_BROKER"
Write-Host "Topic prefix: $env:MQTT_TOPIC_PREFIX"

python $script
if ($LASTEXITCODE) { exit $LASTEXITCODE }
