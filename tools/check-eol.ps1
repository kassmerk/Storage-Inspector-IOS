# Line-ending guard for a repository that is edited on Windows and built on macOS.
#
# A CRLF shell script makes bash die on its very first line ("set: pipefail\r: invalid
# option name"), which looks like a 3-5 second CI failure with no compiler output at all.
# Text files are therefore kept in LF everywhere. The CI workflows strip CR as well, but
# this check catches it locally, before the upload.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\check-eol.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\check-eol.ps1 -Fix
param(
    [string]$Root = (Join-Path $PSScriptRoot '..'),
    [switch]$Fix
)

$Root = (Resolve-Path -LiteralPath $Root).Path
$extensions = @('.swift', '.md', '.html', '.yml', '.yaml', '.sh', '.pbxproj', '.plist', '.xcscheme', '.json')

$files = Get-ChildItem -LiteralPath $Root -Recurse -File |
    Where-Object { $extensions -contains $_.Extension -and $_.FullName -notmatch '[\\/](build|\.git)[\\/]' }

$errors = @()
foreach ($file in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $cr = 0
    foreach ($byte in $bytes) { if ($byte -eq 13) { $cr++ } }
    if ($cr -eq 0) { continue }

    $rel = $file.FullName.Substring($Root.Length).TrimStart('\', '/')
    $errors += ("{0}: {1} CR (CRLF line endings)" -f $rel, $cr)

    if ($Fix) {
        $text = [System.IO.File]::ReadAllText($file.FullName)
        $text = $text -replace "`r`n", "`n" -replace "`r", "`n"
        [System.IO.File]::WriteAllText($file.FullName, $text, (New-Object System.Text.UTF8Encoding($false)))
    }
}

Write-Host ("Checked {0} text files" -f $files.Count)
if ($errors.Count -eq 0) {
    Write-Host "Line endings: OK (LF)"
} elseif ($Fix) {
    $errors | ForEach-Object { Write-Host ("FIXED: " + $_) }
    Write-Host "Line endings: normalized to LF"
} else {
    $errors | ForEach-Object { Write-Host ("ERROR: " + $_) }
    Write-Host "Re-run with -Fix to convert them to LF."
    exit 1
}
