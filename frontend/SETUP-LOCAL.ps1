$ErrorActionPreference = "Stop"

# =====================================================================
# AUTOFORGE APPLICATION 1 - COMPLETE LOCAL FRONTEND ROOT
# Everything frontend-owned lives under D:\AFA-Frontend
# =====================================================================

$Root           = "D:\AFA-Frontend"
$App            = Join-Path $Root "app"
$Cache          = Join-Path $Root "cache"
$NpmCache       = Join-Path $Cache "npm"
$RuntimeCache   = Join-Path $Cache "runtime"
$BrowserProfile = Join-Path $Cache "browser"
$Logs           = Join-Path $Root "logs"
$Temp           = Join-Path $Root "temp"
$Backups        = Join-Path $Root "backups"
$Contracts      = Join-Path $Root "contracts"
$Backend        = "http://localhost:8080"

$Downloads = @(
    "$env:USERPROFILE\Downloads",
    "C:\Users\sauna\Downloads",
    "C:\Users\saunak\Downloads"
) | Select-Object -Unique

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " AUTOFORGE APPLICATION 1 - COMPLETE FRONTEND SETUP" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "ROOT=$Root"

# ---------------------------------------------------------------------
# 1. Create complete frontend-owned filesystem
# ---------------------------------------------------------------------
foreach ($Dir in @(
    $Root,
    $Cache,
    $NpmCache,
    $RuntimeCache,
    $BrowserProfile,
    $Logs,
    $Temp,
    $Backups,
    $Contracts
)) {
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
}

# Direct package/tool caches into AFA-Frontend.
$env:NPM_CONFIG_CACHE     = $NpmCache
$env:npm_config_cache     = $NpmCache
$env:TEMP                 = $Temp
$env:TMP                  = $Temp
$env:XDG_CACHE_HOME       = $RuntimeCache
$env:PYTHONPYCACHEPREFIX  = Join-Path $RuntimeCache "pycache"
$env:PYTHONDONTWRITEBYTECODE = "1"

# ---------------------------------------------------------------------
# 2. Find newest production ZIP in Downloads
# ---------------------------------------------------------------------
$ZipCandidates = @()

foreach ($DownloadDir in $Downloads) {
    if (Test-Path $DownloadDir) {
        $ZipCandidates += Get-ChildItem `
            -Path $DownloadDir `
            -File `
            -Filter "AutoForge-Frontend-Production*.zip" `
            -ErrorAction SilentlyContinue
    }
}

$Zip = $ZipCandidates |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $Zip) {
    throw "AutoForge-Frontend-Production ZIP was not found in Downloads."
}

Write-Host "ZIP=$($Zip.FullName)" -ForegroundColor Green

# ---------------------------------------------------------------------
# 3. Extract entirely inside D:\AFA-Frontend\temp
# ---------------------------------------------------------------------
$Stage = Join-Path $Temp "setup-stage"

if (Test-Path $Stage) {
    Remove-Item $Stage -Recurse -Force
}

New-Item -ItemType Directory -Path $Stage -Force | Out-Null

Expand-Archive `
    -Path $Zip.FullName `
    -DestinationPath $Stage `
    -Force

# ---------------------------------------------------------------------
# 4. Locate exact production package root
# ---------------------------------------------------------------------
$Index = Get-ChildItem `
    -Path $Stage `
    -File `
    -Filter "index.html" `
    -Recurse `
    -ErrorAction SilentlyContinue |
Where-Object {
    $_.FullName -match "[\\/]dist[\\/]index\.html$"
} |
Select-Object -First 1

if (-not $Index) {
    throw "Frontend dist/index.html was not found after extraction."
}

$DistSource = Split-Path -Parent $Index.FullName
$SourceRoot = Split-Path -Parent $DistSource

Write-Host "SOURCE=$SourceRoot" -ForegroundColor Green

# ---------------------------------------------------------------------
# 5. Preserve existing canonical frontend if present
# ---------------------------------------------------------------------
if (Test-Path $App) {
    $Backup = Join-Path $Backups ("app-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    Move-Item $App $Backup
    Write-Host "BACKUP=$Backup" -ForegroundColor Yellow
}

Move-Item $SourceRoot $App

if (Test-Path $Stage) {
    Remove-Item $Stage -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------
# 6. Copy frozen backend API contract into frontend-owned contracts
# ---------------------------------------------------------------------
$ExistingContract = "D:\AutoForge AI\Contracts\openapi.json"

if (Test-Path $ExistingContract) {
    Copy-Item `
        $ExistingContract `
        (Join-Path $Contracts "autoforge-openapi.json") `
        -Force
    Write-Host "OPENAPI_CONTRACT=COPIED" -ForegroundColor Green
}
else {
    Write-Host "OPENAPI_CONTRACT=NOT_FOUND" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------
# 7. Verify production runtime files
# ---------------------------------------------------------------------
$RuntimeConfig = Join-Path $App "dist\prod\runtime-config.js"

if (-not (Test-Path $RuntimeConfig)) {
    throw "runtime-config.js missing from production package."
}

# ---------------------------------------------------------------------
# 8. Run frontend contract tests using cache/temp inside AFA-Frontend
# ---------------------------------------------------------------------
if (Get-Command node -ErrorAction SilentlyContinue) {
    Push-Location $App

    try {
        if (Test-Path "tests\contracts.test.cjs") {
            node tests/contracts.test.cjs 2>&1 |
                Tee-Object -FilePath (Join-Path $Logs "contracts.log") -Append

            if ($LASTEXITCODE -ne 0) {
                throw "Demo contract tests failed."
            }
        }

        if (Test-Path "tests\production-contracts.test.cjs") {
            node tests/production-contracts.test.cjs 2>&1 |
                Tee-Object -FilePath (Join-Path $Logs "production-contracts.log") -Append

            if ($LASTEXITCODE -ne 0) {
                throw "Production contract tests failed."
            }
        }
    }
    finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------------
# 9. Check Application 2 without moving backend files
# ---------------------------------------------------------------------
$BackendReady = $false

try {
    $Health = Invoke-RestMethod `
        -Uri "$Backend/health/ready" `
        -TimeoutSec 5

    $BackendReady = ($Health.status -eq "ready")
}
catch {
    $BackendReady = $false
}

Write-Host "APPLICATION2_READY=$BackendReady"

# ---------------------------------------------------------------------
# 10. Generate permanent frontend launcher at D:\AFA-Frontend
# ---------------------------------------------------------------------
$Starter = Join-Path $Root "Start-Frontend.ps1"

@'
$ErrorActionPreference = "Stop"

$Root           = "D:\AFA-Frontend"
$App            = Join-Path $Root "app"
$Dist           = Join-Path $App "dist"
$Cache          = Join-Path $Root "cache"
$NpmCache       = Join-Path $Cache "npm"
$RuntimeCache   = Join-Path $Cache "runtime"
$BrowserProfile = Join-Path $Cache "browser"
$Logs           = Join-Path $Root "logs"
$Temp           = Join-Path $Root "temp"
$Port           = 5173
$Url            = "http://localhost:$Port"

foreach ($Dir in @($Cache,$NpmCache,$RuntimeCache,$BrowserProfile,$Logs,$Temp)) {
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
}

$env:NPM_CONFIG_CACHE        = $NpmCache
$env:npm_config_cache        = $NpmCache
$env:TEMP                    = $Temp
$env:TMP                     = $Temp
$env:XDG_CACHE_HOME          = $RuntimeCache
$env:PYTHONPYCACHEPREFIX     = Join-Path $RuntimeCache "pycache"
$env:PYTHONDONTWRITEBYTECODE = "1"

if (-not (Test-Path $Dist)) {
    throw "AutoForge frontend dist folder was not found: $Dist"
}

Set-Location $App

try {
    $Health = Invoke-RestMethod `
        -Uri "http://localhost:8080/health/ready" `
        -TimeoutSec 4

    Write-Host "APPLICATION2=$($Health.status)" -ForegroundColor Green
}
catch {
    Write-Host "APPLICATION2=unavailable; demo fallback remains available" -ForegroundColor Yellow
}

# Avoid duplicate static servers.
$PortBusy = Get-NetTCPConnection `
    -LocalPort $Port `
    -State Listen `
    -ErrorAction SilentlyContinue

if ($PortBusy) {
    Write-Host "FRONTEND_ALREADY_RUNNING=True" -ForegroundColor Yellow
}
else {
    $ServerLog = Join-Path $Logs "frontend-server.log"

    Write-Host "FRONTEND_URL=$Url" -ForegroundColor Green
    Write-Host "SERVER_LOG=$ServerLog"

    if (Get-Command python -ErrorAction SilentlyContinue) {
        $ServerCommand = "python -m http.server $Port --directory `"$Dist`" 2>&1 | Tee-Object -FilePath `"$ServerLog`" -Append"
    }
    elseif (Get-Command py -ErrorAction SilentlyContinue) {
        $ServerCommand = "py -m http.server $Port --directory `"$Dist`" 2>&1 | Tee-Object -FilePath `"$ServerLog`" -Append"
    }
    else {
        throw "Python is required to serve the static frontend."
    }

    $ServerArgs = @(
        "-NoExit",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        $ServerCommand
    )

    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList $ServerArgs
}

# Wait until HTTP endpoint responds.
$Ready = $false

for ($i = 1; $i -le 30; $i++) {
    try {
        $Response = Invoke-WebRequest `
            -Uri $Url `
            -TimeoutSec 2 `
            -UseBasicParsing

        if ($Response.StatusCode -ge 200 -and $Response.StatusCode -lt 500) {
            $Ready = $true
            break
        }
    }
    catch {}

    Start-Sleep -Seconds 1
}

if (-not $Ready) {
    throw "Frontend did not become reachable at $Url"
}

Write-Host "FRONTEND_READY=True" -ForegroundColor Green

# Launch browser with its AutoForge-specific profile/cache under D:\AFA-Frontend.
$BrowserCandidates = @(
    "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)

$Browser = $BrowserCandidates |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

if ($Browser) {
    Start-Process `
        -FilePath $Browser `
        -ArgumentList @(
            "--user-data-dir=$BrowserProfile",
            "--disk-cache-dir=$(Join-Path $BrowserProfile 'disk-cache')",
            $Url
        )
}
else {
    Write-Host "No Edge/Chrome executable found for isolated browser cache." -ForegroundColor Yellow
    Write-Host "Open manually: $Url"
}
'@ | Set-Content `
    -Path $Starter `
    -Encoding UTF8

# ---------------------------------------------------------------------
# 11. Start permanent launcher using an argument array (no quote bug)
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " AUTOFORGE APPLICATION 1 INSTALLED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "ROOT=$Root"
Write-Host "APP=$App"
Write-Host "CACHE=$Cache"
Write-Host "LOGS=$Logs"
Write-Host "TEMP=$Temp"
Write-Host "BACKUPS=$Backups"
Write-Host "CONTRACTS=$Contracts"
Write-Host "START_SCRIPT=$Starter"
Write-Host "FRONTEND_URL=http://localhost:5173"

$LauncherArgs = @(
    "-NoExit",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $Starter
)

Start-Process `
    -FilePath "powershell.exe" `
    -ArgumentList $LauncherArgs
