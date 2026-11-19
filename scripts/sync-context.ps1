[CmdletBinding()]
param(
    [string]$Destination = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$files = @(
    (Join-Path $repoRoot 'AGENTS.md'),
    (Join-Path $repoRoot 'README.md'),
    (Join-Path $repoRoot 'docs\PROJECT_CONTEXT.md'),
    (Join-Path $repoRoot 'docs\CURRENT_HANDOFF.md')
)

if ([string]::IsNullOrWhiteSpace($Destination)) {
    $myDrive = Get-ChildItem -LiteralPath 'G:\' -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'Saj*t meghajt*' } |
        Select-Object -First 1

    if ($null -eq $myDrive) {
        throw 'A Google Drive My Drive mappa nem talalhato a G: meghajton.'
    }

    $Destination = Join-Path $myDrive.FullName 'applikacio\trio\context'
}

foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Hianyzo kontextusfajl: $file"
    }
}

$destinationParent = Split-Path -Parent $Destination
if (-not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
    throw "A Google Drive TRIO mappa nem erheto el: $destinationParent"
}

New-Item -ItemType Directory -Path $Destination -Force | Out-Null

foreach ($file in $files) {
    $target = Join-Path $Destination (Split-Path -Leaf $file)
    Copy-Item -LiteralPath $file -Destination $target -Force

    $sourceHash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($sourceHash -ne $targetHash) {
        throw "Sikertelen kontextusellenorzes: $target"
    }
}

Write-Host "TRIO kontextus elmentve: $Destination" -ForegroundColor Green
