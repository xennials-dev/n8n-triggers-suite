# sync.ps1
# Stashes local changes, pulls latest upstream changes with rebase, and restores local changes

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "   Syncing n8n Suite with Upstream GitHub Repo         " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

Write-Host "`n[1/3] Stashing local changes (including untracked)..." -ForegroundColor Yellow
$stashOutput = git stash --include-untracked
$stashed = -not ($stashOutput -match "No local changes to save")
Write-Host "      $stashOutput" -ForegroundColor Gray

Write-Host "`n[2/3] Pulling and rebasing from upstream origin/main..." -ForegroundColor Cyan
git pull --rebase origin main

if ($stashed) {
    Write-Host "`n[3/3] Restoring your local stashed changes..." -ForegroundColor Green
    git stash pop
} else {
    Write-Host "`n[3/3] Working directory was clean. Nothing to restore." -ForegroundColor Gray
}

Write-Host "`nSync complete! Your branch is up to date with upstream." -ForegroundColor Green
