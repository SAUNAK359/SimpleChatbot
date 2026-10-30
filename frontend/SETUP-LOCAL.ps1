$ErrorActionPreference = "Stop"

$Root       = "D:\AutoForge AI"
$Target     = Join-Path $Root "Application1"
$Backend    = "http://localhost:8080"
$Downloads  = @("$env:USERPROFILE\Downloads","C:\Users\sauna\Downloads","C:\Users\saunak\Downloads") | Select-Object -Unique

Write-Host "" 
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " AUTOFORGE APPLICATION 1 — LOCAL PRODUCTION BOOTSTRAP" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$zip = foreach($d in $Downloads){
    if(Test-Path $d){
        Get-ChildItem $d -File -Filter "AutoForge-Frontend-Production*.zip" -ErrorAction SilentlyContinue
    }
} | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if(-not $zip){
    throw "AutoForge-Frontend-Production ZIP was not found in Downloads."
}

Write-Host "ZIP=$($zip.FullName)" -ForegroundColor Green
New-Item -ItemType Directory -Path $Root -Force | Out-Null

$stage = Join-Path $Root "_app1_stage"
if(Test-Path $stage){ Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null
Expand-Archive -Path $zip.FullName -DestinationPath $stage -Force

$index = Get-ChildItem $stage -File -Filter "index.html" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "[\\/]dist[\\/]index\.html$" } |
    Select-Object -First 1
if(-not $index){ throw "Frontend dist/index.html was not found after extraction." }

$source = Split-Path -Parent (Split-Path -Parent $index.FullName)
if(Test-Path $Target){
    $backup = "$Target-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Move-Item $Target $backup
    Write-Host "BACKUP=$backup" -ForegroundColor Yellow
}
Move-Item $source $Target
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue

# Production defaults. Runtime-config reads localStorage first, then these defaults.
$runtime = Join-Path $Target "dist\prod\runtime-config.js"
if(-not (Test-Path $runtime)){ throw "runtime-config.js missing from production package." }

# Contract checks
if(Get-Command node -ErrorAction SilentlyContinue){
    Push-Location $Target
    try {
        node tests/contracts.test.cjs
        if($LASTEXITCODE -ne 0){ throw "Demo contract tests failed." }
        node tests/production-contracts.test.cjs
        if($LASTEXITCODE -ne 0){ throw "Production contract tests failed." }
    }
    finally { Pop-Location }
}

$backendReady = $false
try {
    $h = Invoke-RestMethod "$Backend/health/ready" -TimeoutSec 5
    $backendReady = ($h.status -eq "ready")
} catch {}

Write-Host "APPLICATION2_READY=$backendReady"

$starter = Join-Path $Root "Start-Frontend.ps1"
@'
$ErrorActionPreference = "Stop"
$Root = "D:\AutoForge AI\Application1"
$Dist = Join-Path $Root "dist"
$Port = 5173
Set-Location $Root
try {
    $h = Invoke-RestMethod "http://localhost:8080/health/ready" -TimeoutSec 4
    Write-Host "APPLICATION2=$($h.status)" -ForegroundColor Green
} catch {
    Write-Host "APPLICATION2=unavailable; demo fallback remains available" -ForegroundColor Yellow
}
if(Get-Command python -ErrorAction SilentlyContinue){
    Write-Host "FRONTEND_URL=http://localhost:$Port" -ForegroundColor Green
    python -m http.server $Port --directory "$Dist"
} elseif(Get-Command py -ErrorAction SilentlyContinue){
    Write-Host "FRONTEND_URL=http://localhost:$Port" -ForegroundColor Green
    py -m http.server $Port --directory "$Dist"
} else {
    throw "Python is required to serve the static frontend."
}
'@ | Set-Content $starter -Encoding UTF8

Write-Host "" 
Write-Host "============================================================" -ForegroundColor Green
Write-Host " AUTOFORGE APPLICATION 1 INSTALLED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "ROOT=$Target"
Write-Host "START_SCRIPT=$starter"
Write-Host "FRONTEND_URL=http://localhost:5173"

Start-Process powershell.exe -ArgumentList '-NoExit','-ExecutionPolicy','Bypass','-File',"`"$starter`""
Start-Sleep -Seconds 2
Start-Process "http://localhost:5173"
