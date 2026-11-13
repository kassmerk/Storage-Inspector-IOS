# Collects the app list of a connected iPhone into plain text that Storage Inspector can import.
#
# On iOS 26 a sandboxed build cannot read the installed-app list, so the list has to be collected
# where iOS does allow it: on a computer with the device paired. This script runs
# `ideviceinstaller -l -o list_all` (libimobiledevice — no jailbreak, no Developer Mode, only the
# usual "Trust this computer") and writes the output to app-list.txt, which the app reads as it is
# in Settings > Import app list.
param(
    [string]$Output = (Join-Path (Get-Location) 'app-list.txt'),
    [string]$Device = '',
    [switch]$UserOnly
)

$ErrorActionPreference = 'Stop'

function Find-IdeviceInstaller {
    $candidates = @()

    $onPath = Get-Command 'ideviceinstaller' -ErrorAction SilentlyContinue
    if ($onPath) { $candidates += $onPath.Source }

    $candidates += (Join-Path $PSScriptRoot 'libimobiledevice\ideviceinstaller.exe')
    $candidates += (Join-Path $PSScriptRoot 'libimobiledevice\bin\ideviceinstaller.exe')

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    return $null
}

$tool = Find-IdeviceInstaller

if (-not $tool) {
    Write-Host 'ideviceinstaller was not found.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'A sandboxed app cannot read the installed-app list on iOS 26, so it has to be'
    Write-Host 'collected on the computer. Three ways, none of them needs a jailbreak:'
    Write-Host ''
    Write-Host '  1. libimobiledevice (this script)'
    Write-Host '     - unzip a Windows build into tools\libimobiledevice\ or add it to PATH'
    Write-Host '     - connect the iPhone, tap "Trust", run this script again'
    Write-Host '     - https://libimobiledevice.org (Windows builds are linked from its download page)'
    Write-Host '  2. A desktop tool that lists installed apps, e.g. 3uTools: export or copy the rows.'
    Write-Host '  3. On the iPhone: Settings > General > iPhone Storage lists every app and its size.'
    Write-Host ''
    Write-Host 'Then paste the text into Storage Inspector > Settings > Import app list.'
    exit 2
}

$arguments = @('-l')
if (-not $UserOnly) { $arguments += @('-o', 'list_all') }
if ($Device) { $arguments += @('-u', $Device) }

Write-Host ("Running: {0} {1}" -f $tool, ($arguments -join ' '))
$lines = & $tool @arguments 2>&1
if ($LASTEXITCODE -ne 0) {
    $lines | ForEach-Object { Write-Host $_ }
    throw 'ideviceinstaller failed: is the iPhone connected, unlocked and trusted?'
}

$text = ($lines | ForEach-Object { "$_" }) -join "`r`n"
[System.IO.File]::WriteAllText($Output, $text, (New-Object System.Text.UTF8Encoding($false)))

$appRows = @($lines | Where-Object { $_ -match '^[A-Za-z0-9][A-Za-z0-9._-]*\.[A-Za-z0-9._-]+' })

Write-Host ''
Write-Host ("Wrote {0} lines ({1} app rows) to {2}" -f @($lines).Count, $appRows.Count, $Output) -ForegroundColor Green
Write-Host ''
Write-Host 'Next: get the file onto the iPhone (AirDrop, iCloud Drive, Files, email) and import it'
Write-Host 'in Storage Inspector > Settings > Import app list — the sheet also opens .txt and .csv'
Write-Host 'files picked with "Choose file".'
