# test-triggers.ps1
# Automates testing for n8n local triggers: File Watcher, Webhook, Zero-Auth, and Tunneling

param (
    [string]$Target = "all", # 'file', 'webhook', 'auth', 'tunnel', or 'all'
    [string]$BaseUrl = "http://localhost:5678"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WatchFolder = Join-Path $ScriptDir "watch_folder"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   n8n Local Automation Test Suite        " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

function Test-AuthBypass {
    Write-Host "`n[Auth] Testing Zero-Click Auto-Authentication..." -ForegroundColor Yellow
    try {
        $req = [System.Net.HttpWebRequest]::Create("$BaseUrl/")
        $req.AllowAutoRedirect = $false
        $req.Timeout = 5000
        $response = $req.GetResponse()
        $statusCode = [int]$response.StatusCode
        $setCookie = $response.Headers["Set-Cookie"]
        $location = $response.Headers["Location"]
        $response.Close()

        if ($statusCode -eq 302 -and ($location -like "*workflow*" -or $location -eq "/home/workflows")) {
            Write-Host "  [+] Zero-Click Proxy is active! Redirected to: $location" -ForegroundColor Green
            Write-Host "  [+] Received Session Cookie: $(if ($setCookie) { $setCookie.Substring(0, [Math]::Min(35, $setCookie.Length)) + '...' } else { 'none' })" -ForegroundColor Green
        } elseif ($statusCode -eq 200) {
            Write-Host "  [+] n8n endpoint responded with HTTP 200 OK directly." -ForegroundColor Green
        } else {
            Write-Host "  [-] Unexpected response: HTTP $statusCode" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [-] n8n stack is not currently listening on $BaseUrl." -ForegroundColor Yellow
        Write-Host "      Run '.\start-n8n.ps1' to boot up the instance." -ForegroundColor Gray
    }
}

function Test-FileTrigger {
    Write-Host "`n[1/3] Testing Local File Trigger..." -ForegroundColor Yellow
    if (-not (Test-Path $WatchFolder)) {
        New-Item -ItemType Directory -Path $WatchFolder -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $testFile = Join-Path $WatchFolder "event_test_$timestamp.json"
    
    $payload = @{
        trigger = "localFileTrigger"
        timestamp = (Get-Date).ToString("o")
        event = "file_added"
        message = "Test event created by test-triggers.ps1"
    } | ConvertTo-Json -Depth 3

    Set-Content -Path $testFile -Value $payload
    Write-Host "  [+] Dropped new test file: $testFile" -ForegroundColor Green
    Write-Host "  -> If n8n workflow is active, 'Local File Trigger' will process this immediately." -ForegroundColor Gray
}

function Test-WebhookTrigger {
    Write-Host "`n[2/3] Testing Webhook Trigger..." -ForegroundColor Yellow
    
    # Try production webhook first, then test webhook endpoint
    $prodUrl = "$BaseUrl/webhook/local-api-webhook"
    $testUrl = "$BaseUrl/webhook-test/local-api-webhook"
    
    $body = @{
        event = "user_action"
        source = "test-triggers.ps1"
        data = @{
            greeting = "Hello from local automation!"
            time = (Get-Date).ToString("o")
        }
    } | ConvertTo-Json -Depth 4

    Write-Host "  Sending POST request to: $prodUrl (and $testUrl if not activated)..." -ForegroundColor Gray
    
    try {
        $response = Invoke-RestMethod -Uri $prodUrl -Method Post -Body $body -ContentType "application/json" -TimeoutSec 3 -ErrorAction Stop
        Write-Host "  [+] Successfully reached Production Webhook!" -ForegroundColor Green
        Write-Host "  Response received: $($response | ConvertTo-Json -Compress)" -ForegroundColor Green
    }
    catch {
        Write-Host "  [-] Production webhook not listening (workflow may be in draft/inactive mode)." -ForegroundColor Yellow
        Write-Host "  Trying Test Webhook endpoint: $testUrl ..." -ForegroundColor Gray
        try {
            $response = Invoke-RestMethod -Uri $testUrl -Method Post -Body $body -ContentType "application/json" -TimeoutSec 3 -ErrorAction Stop
            Write-Host "  [+] Successfully reached Test Webhook!" -ForegroundColor Green
            Write-Host "  Response received: $($response | ConvertTo-Json -Compress)" -ForegroundColor Green
        }
        catch {
            Write-Host "  [-] Could not reach webhook endpoint: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  -> Note: Make sure n8n is running at $BaseUrl and either the workflow is Activated OR you clicked 'Listen for test event' in the UI." -ForegroundColor DarkYellow
        }
    }
}

function Show-TunnelHelper {
    Write-Host "`n[3/3] External Webhook Tunneling (Cloudflare / ngrok)..." -ForegroundColor Yellow
    Write-Host "  To expose your local n8n instance to external services (GitHub, Stripe, Telegram):" -ForegroundColor Gray
    Write-Host "  Run:" -ForegroundColor White
    Write-Host "    cloudflared tunnel --url http://localhost:5678" -ForegroundColor Green
    Write-Host "  Or with ngrok:" -ForegroundColor White
    Write-Host "    ngrok http 5678" -ForegroundColor Green
    Write-Host "`n  Once running, set n8n environment variable WEBHOOK_URL to your public tunnel HTTPS URL." -ForegroundColor Gray
}

switch ($Target.ToLower()) {
    "auth"    { Test-AuthBypass }
    "file"    { Test-FileTrigger }
    "webhook" { Test-WebhookTrigger }
    "tunnel"  { Show-TunnelHelper }
    default   { 
        Test-AuthBypass
        Test-FileTrigger
        Test-WebhookTrigger
        Show-TunnelHelper
    }
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "Test routine completed." -ForegroundColor Cyan
