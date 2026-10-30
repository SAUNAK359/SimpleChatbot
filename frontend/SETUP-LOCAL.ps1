$ErrorActionPreference = "Stop"

$Root       = "D:\AutoForge AI"
$Target     = Join-Path $Root "Application1"
$Backend    = "http://localhost:8080"
$Downloads  = @(
    "$env:USERPROFILE\Downloads",
    "C:\Users\sauna\Downloads",
    "C:\Users\saunak\Downloads"
) | Select-Object -Unique

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " AUTOFORGE APPLICATION 1 - LOCAL PRODUCTION BOOTSTRAP" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ---------------------------------------------------------------------
# 1. Find newest production ZIP in Downloads
# ---------------------------------------------------------------------
$zip = foreach ($d in $Downloads) {
    if (Test-Path $d) {
        Get-ChildItem `
            -Path $d `
            -File `
            -Filter "AutoForge-Frontend-Production*.zip" `
            -ErrorAction SilentlyContinue
    }
} | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $zip) {
    throw "AutoForge-Frontend-Production ZIP was not found in Downloads."
}

Write-Host "ZIP=$($zip.FullName)" -ForegroundColor Green

New-Item `
    -ItemType Directory `
    -Path $Root `
    -Force | Out-Null

# ---------------------------------------------------------------------
# 2. Extract into temporary staging directory
# ---------------------------------------------------------------------
$stage = Join-Path $Root "_app1_stage"

if (Test-Path $stage) {
    Remove-Item $stage -Recurse -Force
}

New-Item `
    -ItemType Directory `
    -Path $stage `
    -Force | Out-Null

Expand-Archive `
    -Path $zip.FullName `
    -DestinationPath $stage `
    -Force

# ---------------------------------------------------------------------
# 3. Locate production package root
# ---------------------------------------------------------------------
$index = Get-ChildItem `
    -Path $stage `
    -File `
    -Filter "index.html" `
    -Recurse `
    -ErrorAction SilentlyContinue |
Where-Object {
    $_.FullName -match "[\\/]dist[\\/]index\.html$"
} |
Select-Object -First 1

if (-not $index) {
    throw "Frontend dist/index.html was not found after extraction."
}

# index.html -> dist -> production package root
$dist   = Split-Path -Parent $index.FullName
$source = Split-Path -Parent $dist

Write-Host "SOURCE=$source" -ForegroundColor Green

# ---------------------------------------------------------------------
# 4. Preserve existing Application1 before replacement
# ---------------------------------------------------------------------
if (Test-Path $Target) {
    $backup = "$Target-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Move-Item $Target $backup
    Write-Host "BACKUP=$backup" -ForegroundColor Yellow
}

Move-Item $source $Target

Remove-Item `
    $stage `
    -Recurse `
    -Force `
    -ErrorAction SilentlyContinue

# ---------------------------------------------------------------------
# 5. Verify production runtime
# ---------------------------------------------------------------------
$runtime = Join-Path $Target "dist\prod\runtime-config.js"

if (-not (Test-Path $runtime)) {
    throw "runtime-config.js missing from production package."
}

# ---------------------------------------------------------------------
# 6. Contract checks
# ---------------------------------------------------------------------
if (Get-Command node -ErrorAction SilentlyContinue) {
    Push-Location $Target

    try {
        if (Test-Path "tests\contracts.test.cjs") {
            node tests/contracts.test.cjs

            if ($LASTEXITCODE -ne 0) {
                throw "Demo contract tests failed."
            }
        }

        if (Test-Path "tests\production-contracts.test.cjs") {
            node tests/production-contracts.test.cjs

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
# 7. Check Application 2
# ---------------------------------------------------------------------
$backendReady = $false

try {
    $h = Invoke-RestMethod `
        -Uri "$Backend/health/ready" `
        -TimeoutSec 5

    $backendReady = ($h.status -eq "ready")
}
catch {
    $backendReady = $false
}

Write-Host "APPLICATION2_READY=$backendReady"

# ---------------------------------------------------------------------
# 8. Create permanent frontend launcher
# ---------------------------------------------------------------------
$starter = Join-Path $Root "Start-Frontend.ps1"

@'
$ErrorActionPreference = "Stop"

$Root = "D:\AutoForge AI\Application1"
$Dist = Join-Path $Root "dist"
$Port = 5173

if (-not (Test-Path $Dist)) {
    throw "AutoForge frontend dist folder was not found: $Dist"
}

Set-Location $Root

try {
    $h = Invoke-RestMethod `
        -Uri "http://localhost:8080/health/ready" `
        -TimeoutSec 4

    Write-Host "APPLICATION2=$($h.status)" -ForegroundColor Green
}
catch {
    Write-Host "APPLICATION2=unavailable; demo fallback remains available" -ForegroundColor Yellow
}

Write-Host "FRONTEND_URL=http://localhost:$Port" -ForegroundColor Green

if (Get-Command python -ErrorAction SilentlyContinue) {
    python -m http.server $Port --directory $Dist
}
elif (Get-Command py -ErrorAction SilentlyContinue) {
    py -m http.server $Port --directory $Dist
}
else {
    throw "Python is required to serve the static frontend."
}
'@ | Set-Content `
    -Path $starter `
    -Encoding UTF8

# Correct accidental Python-style keyword if present in generated launcher.
$starterText = Get-Content $starter -Raw
$starterText = $starterText -replace '(?m)^elif \(', 'elseif ('
Set-Content -Path $starter -Value $starterText -Encoding UTF8

# ---------------------------------------------------------------------
# 9. Start frontend without nested quote escaping
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " AUTOFORGE APPLICATION 1 INSTALLED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "ROOT=$Target"
Write-Host "START_SCRIPT=$starter"
Write-Host "FRONTEND_URL=http://localhost:5173"

$frontendArgs = @(
    "-NoExit",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $starter
)

Start-Process `
    -FilePath "powershell.exe" `
    -ArgumentList $frontendArgs

# ---------------------------------------------------------------------
# 10. Wait for frontend and open browser
# ---------------------------------------------------------------------
$frontendReady = $false

for ($i = 1; $i -le 30; $i++) {
    try {
        $response = Invoke-WebRequest `
            -Uri "http://localhost:5173" `
            -TimeoutSec 2 `
            -UseBasicParsing

        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
            $frontendReady = $true
            break
        }
    }
    catch {}

    Start-Sleep -Seconds 1
}

if ($frontendReady) {
    Write-Host "FRONTEND_READY=True" -ForegroundColor Green
    Start-Process -FilePath "http://localhost:5173"
}
else {
    Write-Host "FRONTEND_READY=STARTING" -ForegroundColor Yellow
    Write-Host "Check the frontend PowerShell window for details."
}
