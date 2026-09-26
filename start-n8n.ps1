# start-n8n.ps1
# Clean local launcher for n8n Automation Stack

param (
    [ValidateSet("local", "docker")]
    [string]$Mode = "local",
    [switch]$OpenBrowser = $true
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "   Starting n8n Local Automation Stack                 " -ForegroundColor Cyan
Write-Host "   URL: http://localhost:5678                          " -ForegroundColor Yellow
Write-Host "   Login: admin@local.dev / LocalDevPassword123!       " -ForegroundColor Gray
Write-Host "=======================================================" -ForegroundColor Cyan

if ($Mode -eq "docker") {
    Write-Host "Starting via Docker Compose..." -ForegroundColor Green
    docker compose up -d
    Write-Host "n8n running in background! Open http://localhost:5678" -ForegroundColor Green
    if ($OpenBrowser) { Start-Process "http://localhost:5678" }
} else {
    Write-Host "Starting n8n locally on port 5678..." -ForegroundColor Green
    Write-Host "(Press Ctrl+C anytime to stop)" -ForegroundColor Gray
    
    if ($OpenBrowser) {
        Start-Job -ScriptBlock {
            Start-Sleep -Seconds 3
            Start-Process "http://localhost:5678"
        } | Out-Null
    }

    n8n start
}
