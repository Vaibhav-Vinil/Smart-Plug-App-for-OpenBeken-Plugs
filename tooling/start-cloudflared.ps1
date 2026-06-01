$root = Split-Path -Parent $PSScriptRoot
$config = Get-Content (Join-Path $root "backend.config.json") | ConvertFrom-Json
$tunnelFile = Join-Path $root "tunnel.url"

$exe = $config.cloudflaredExe
if (-not (Test-Path $exe)) {
    Write-Error "cloudflared not found at: $exe"
    exit 1
}

Write-Host "Starting Cloudflare tunnel -> http://localhost:9001"
Write-Host "When a URL appears below, set Global bridge URL in the app to: wss://<host>/mqtt"
Write-Host "It will also be written to tunnel.url in the project folder."
Write-Host ""

# cloudflared logs to stderr; do not treat that as a PowerShell error.
$ErrorActionPreference = "Continue"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

function Write-TunnelLine {
    param([string]$Line)
    if ([string]::IsNullOrWhiteSpace($Line)) { return }
    Write-Host $Line
    if ($Line -match 'https://([a-z0-9-]+)\.trycloudflare\.com') {
        $wss = "wss://$($Matches[1]).trycloudflare.com/mqtt"
        Set-Content -Path $tunnelFile -Value $wss -Encoding utf8
        Write-Host ""
        Write-Host ">>> Global bridge URL for the app: $wss" -ForegroundColor Green
        Write-Host ""
    }
}

& $exe tunnel --url http://localhost:9001 2>&1 | ForEach-Object { Write-TunnelLine "$_" }

if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
