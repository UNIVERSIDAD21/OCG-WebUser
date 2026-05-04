$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Step {
    param(
        [string]$Title,
        [scriptblock]$Action
    )

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    & $Action
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$functionsDir = Join-Path $projectRoot 'functions'

Write-Host "Kit local de validación OCG (Windows)" -ForegroundColor Green
Write-Host "Este script NO despliega, NO configura credenciales y NO borra archivos." -ForegroundColor Yellow
Write-Host "Requiere Android SDK para validar 'flutter build apk --debug'." -ForegroundColor Yellow

Set-Location $projectRoot

Invoke-Step "1) Flutter version" {
    flutter --version
}

Invoke-Step "2) Flutter doctor -v" {
    flutter doctor -v
}

Invoke-Step "3) Flutter pub get" {
    flutter pub get
}

Invoke-Step "4) Flutter analyze" {
    flutter analyze
}

Invoke-Step "5) Flutter test" {
    flutter test
}

Invoke-Step "6) Flutter build apk --debug" {
    flutter build apk --debug
}

Set-Location $functionsDir

Invoke-Step "7) npm ci (functions)" {
    npm ci
}

Invoke-Step "8) npm run build (functions)" {
    npm run build
}

Invoke-Step "9) node --test test/*.test.mjs (functions)" {
    node --test test/*.test.mjs
}

Write-Host "" 
Write-Host "Validación local completada correctamente." -ForegroundColor Green
Write-Host "Recuerda consolidar la evidencia en docs/checklists/EVIDENCIA_VALIDACION_HUMANA.md" -ForegroundColor Green
