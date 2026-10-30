$ErrorActionPreference = "Stop"

$Root           = "D:\AFA-Frontend"
$App            = Join-Path $Root "app"
$Dist           = Join-Path $App "dist"
$Runtime        = Join-Path $Root "runtime"
$Cache          = Join-Path $Root "cache"
$NpmCache       = Join-Path $Cache "npm"
$RuntimeCache   = Join-Path $Cache "runtime"
$BrowserProfile = Join-Path $Cache "browser"
$Logs           = Join-Path $Root "logs"
$Temp           = Join-Path $Root "temp"
$ServerScript   = Join-Path $Runtime "static-server.cjs"
$ServerLog      = Join-Path $Logs "frontend-server.log"
$Port           = 5173
$Url            = "http://localhost:$Port"

foreach ($Dir in @($Root,$Runtime,$Cache,$NpmCache,$RuntimeCache,$BrowserProfile,$Logs,$Temp)) {
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
}

if (-not (Test-Path $Dist)) {
    throw "AutoForge frontend dist folder was not found: $Dist"
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js is required for the AutoForge frontend server but node.exe is not available in PATH."
}

$env:NPM_CONFIG_CACHE = $NpmCache
$env:npm_config_cache = $NpmCache
$env:TEMP = $Temp
$env:TMP = $Temp
$env:XDG_CACHE_HOME = $RuntimeCache
$env:AFA_FRONTEND_DIST = $Dist
$env:AFA_FRONTEND_PORT = "$Port"
$env:AFA_FRONTEND_HOST = "127.0.0.1"

try {
    $Health = Invoke-RestMethod -Uri "http://localhost:8080/health/ready" -TimeoutSec 4
    Write-Host "APPLICATION2=$($Health.status)" -ForegroundColor Green
}
catch {
    Write-Host "APPLICATION2=unavailable; frontend demo fallback remains available" -ForegroundColor Yellow
}

$PortBusy = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue

if (-not $PortBusy) {
    if (-not (Test-Path $ServerScript)) {
        throw "Node server script missing: $ServerScript"
    }

    $Command = "node `"$ServerScript`" 2>&1 | Tee-Object -FilePath `"$ServerLog`" -Append"

    Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-NoExit",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        $Command
    )
}
else {
    Write-Host "FRONTEND_ALREADY_RUNNING=True" -ForegroundColor Yellow
}

$Ready = $false

for ($i = 1; $i -le 30; $i++) {
    try {
        $Response = Invoke-WebRequest -Uri $Url -TimeoutSec 2 -UseBasicParsing
        if ($Response.StatusCode -ge 200 -and $Response.StatusCode -lt 500) {
            $Ready = $true
            break
        }
    }
    catch {}

    Start-Sleep -Seconds 1
}

if (-not $Ready) {
    throw "Frontend did not become reachable at $Url. Check $ServerLog"
}

Write-Host "FRONTEND_READY=True" -ForegroundColor Green
Write-Host "FRONTEND_URL=$Url" -ForegroundColor Green
Write-Host "SERVER=node" -ForegroundColor Green
Write-Host "SERVER_LOG=$ServerLog"

$BrowserCandidates = @(
    "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)

$Browser = $BrowserCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($Browser) {
    Start-Process -FilePath $Browser -ArgumentList @(
        "--user-data-dir=$BrowserProfile",
        "--disk-cache-dir=$(Join-Path $BrowserProfile 'disk-cache')",
        $Url
    )
}
else {
    Write-Host "Open manually: $Url" -ForegroundColor Yellow
}
