# uninstall-autostart.ps1
# Removes n8n from Windows auto-start

$StartupFolder = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Startup)
$TargetFile = Join-Path $StartupFolder "Start-n8n-local.vbs"

if (Test-Path $TargetFile) {
    Remove-Item -Path $TargetFile -Force
    Write-Host "Removed n8n auto-start from: $TargetFile" -ForegroundColor Yellow
} else {
    Write-Host "Auto-start file was not found in: $TargetFile" -ForegroundColor Gray
}
