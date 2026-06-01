# Stops leftover backend processes before Ctrl+F5 / preLaunchTask restarts them.
$ErrorActionPreference = "SilentlyContinue"

function Stop-ProcTree {
    param([int]$ProcessId)
    $children = Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue
    foreach ($child in $children) {
        Stop-ProcTree -ProcessId $child.ProcessId
    }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

Write-Host "Cleaning up previous Smart Plug backend processes..."

$cloudflared = Get-Process cloudflared -ErrorAction SilentlyContinue
if ($cloudflared) {
  foreach ($p in $cloudflared) {
    Write-Host "  Stopping cloudflared (PID $($p.Id))"
    Stop-ProcTree -ProcessId $p.Id
  }
  Start-Sleep -Milliseconds 500
}

$recorders = Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -like "*mqtt_recorder.py*" }
foreach ($proc in $recorders) {
  Write-Host "  Stopping mqtt_recorder (PID $($proc.ProcessId))"
  Stop-ProcTree -ProcessId $proc.ProcessId
}

$mosquitto = Get-Process mosquitto -ErrorAction SilentlyContinue
if ($mosquitto) {
  foreach ($p in $mosquitto) {
    Write-Host "  Stopping mosquitto (PID $($p.Id))"
    Stop-ProcTree -ProcessId $p.Id
  }
  $deadline = (Get-Date).AddSeconds(5)
  while ((Get-Date) -lt $deadline) {
    if (-not (Get-NetTCPConnection -LocalPort 1883 -State Listen -ErrorAction SilentlyContinue)) {
      break
    }
    Start-Sleep -Milliseconds 200
  }
}

Write-Host "Cleanup finished."
exit 0
