[CmdletBinding()]
param(
    [switch]$InstallDependencies
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$mobileRoot = Join-Path $repoRoot 'mobile'

function Test-Command {
    param([Parameter(Mandatory)][string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        Write-Warning "$Name nincs telepitve vagy nincs benne a PATH-ban."
        return $false
    }

    Write-Host "[OK] $Name -> $($command.Source)" -ForegroundColor Green
    return $true
}

Write-Host 'TRIO fejlesztoi kornyezet ellenorzese' -ForegroundColor Cyan
Write-Host "Repo: $repoRoot"

$hasGit = Test-Command git
$hasFlutter = Test-Command flutter
$hasPhp = Test-Command php
$hasComposer = Test-Command composer

if ($hasFlutter) {
    flutter --version
    flutter doctor
}

if ($hasPhp) {
    php --version
}

if ($hasComposer) {
    composer --version
}

if ($InstallDependencies) {
    if ($hasFlutter) {
        Push-Location $mobileRoot
        try {
            flutter pub get
        }
        finally {
            Pop-Location
        }
    }

    if ($hasComposer) {
        Push-Location $repoRoot
        try {
            composer install
        }
        finally {
            Pop-Location
        }
    }
}

Write-Host ''
Write-Host 'Helyi, Gitben nem tarolt fajlok:' -ForegroundColor Yellow
Write-Host '  - .env (Laravel)'
Write-Host '  - mobile/android/local.properties'
Write-Host '  - mobile/android/key.properties (csak alairt release buildhez)'
Write-Host '  - mobile/android/*.jks (csak alairt release buildhez)'
Write-Host ''
Write-Host 'Javasolt projektutvonal: C:\dev\trio-cardgame' -ForegroundColor Cyan
