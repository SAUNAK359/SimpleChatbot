$ErrorActionPreference = "Stop"

$Root = "D:\AFA-Frontend"
$Runtime = Join-Path $Root "runtime"
$Launcher = Join-Path $Root "Start-Frontend.ps1"
$Server = Join-Path $Runtime "static-server.cjs"

New-Item -ItemType Directory -Path $Runtime -Force | Out-Null

$Base = "https://raw.githubusercontent.com/SAUNAK359/SimpleChatbot/autoforge-frontend-production/frontend"

Invoke-WebRequest `
    -Uri "$Base/runtime/static-server.cjs" `
    -OutFile $Server

Invoke-WebRequest `
    -Uri "$Base/Start-Frontend-Node.ps1" `
    -OutFile $Launcher

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js is not available in PATH."
}

Write-Host "NODE=$(node --version)" -ForegroundColor Green
Write-Host "SERVER=$Server" -ForegroundColor Green
Write-Host "LAUNCHER=$Launcher" -ForegroundColor Green

# Stop only an existing listener on the frontend port if it is a stale process.
$Connections = Get-NetTCPConnection -LocalPort 5173 -State Listen -ErrorAction SilentlyContinue
foreach ($Connection in $Connections) {
    if ($Connection.OwningProcess) {
        try {
            Stop-Process -Id $Connection.OwningProcess -Force -ErrorAction Stop
        }
        catch {}
    }
}

Set-ExecutionPolicy -Scope Process Bypass -Force
& $Launcher
