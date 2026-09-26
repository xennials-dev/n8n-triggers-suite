# install-autostart.ps1
# Configures n8n to start automatically in the background when Windows boots

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VbsPath = Join-Path $ScriptDir "start-n8n-silent.vbs"
$StartupFolder = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Startup)
$TargetFile = Join-Path $StartupFolder "Start-n8n-local.vbs"

Copy-Item -Path $VbsPath -Destination $TargetFile -Force

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "   n8n Windows Auto-Start Configured                   " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "Installed to: $TargetFile" -ForegroundColor Green
Write-Host "n8n will now launch silently in the background on system startup." -ForegroundColor Yellow
