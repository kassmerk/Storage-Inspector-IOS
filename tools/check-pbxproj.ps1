# Sanity checks for the hand written project.pbxproj:
#  * braces are balanced
#  * every 24 hex character UUID that is referenced is also defined
param(
    [string]$Project = (Join-Path $PSScriptRoot '..\StorageInspector.xcodeproj\project.pbxproj')
)

$text = Get-Content -LiteralPath $Project -Raw
$errors = @()

$open = ([regex]::Matches($text, '\{')).Count
$close = ([regex]::Matches($text, '\}')).Count
if ($open -ne $close) { $errors += "Braces unbalanced: $open open vs $close close" }

$defined = New-Object System.Collections.Generic.HashSet[string]
foreach ($m in [regex]::Matches($text, '(?m)^\t\t([0-9A-Fa-f]{24})(?: /\*[^\r\n]*?\*/)? = \{')) {
    [void]$defined.Add($m.Groups[1].Value.ToUpper())
}

$used = New-Object System.Collections.Generic.HashSet[string]
foreach ($m in [regex]::Matches($text, '[0-9A-Fa-f]{24}')) {
    [void]$used.Add($m.Value.ToUpper())
}

$missing = $used | Where-Object { -not $defined.Contains($_) }
if ($missing) { $errors += ("Used but not defined: " + ($missing -join ', ')) }

$sections = [regex]::Matches($text, '/\* (Begin|End) ([A-Za-z]+) section \*/')
$beign = @{}
foreach ($s in $sections) {
    $kind = $s.Groups[1].Value
    $name = $s.Groups[2].Value
    if ($kind -eq 'Begin') {
        if ($beign.ContainsKey($name)) { $errors += "Section '$name' begun twice" }
        $beign[$name] = $true
    }
}
$endSections = $sections | Where-Object { $_.Groups[1].Value -eq 'End' } | ForEach-Object { $_.Groups[2].Value }
foreach ($name in $beign.Keys) {
    if ($endSections -notcontains $name) { $errors += "Section '$name' is never closed" }
}

Write-Host ("Defined objects: " + $defined.Count + ", referenced UUIDs: " + $used.Count)
if ($errors.Count -eq 0) {
    Write-Host "project.pbxproj: OK"
} else {
    $errors | ForEach-Object { Write-Host ("ERROR: " + $_) }
    exit 1
}
