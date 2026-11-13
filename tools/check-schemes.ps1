$ErrorActionPreference = 'Stop'
$root = 'd:\NewLoofInternal+source\StorageInspector'
$plist = Join-Path $root 'StorageInspector\Resources\Info.plist'
$swift = Join-Path $root 'StorageInspector\Services\AppSchemeProbe.swift'

[xml]$xml = Get-Content -LiteralPath $plist -Raw
$declared = @($xml.plist.dict.array.string)

$swiftText = Get-Content -LiteralPath $swift -Raw
$swiftSchemes = @([regex]::Matches($swiftText, 'scheme: "([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$swiftBundles = @([regex]::Matches($swiftText, 'bundleID: "([^"]+)"') | ForEach-Object { $_.Groups[1].Value })

Write-Host ("plist schemes:  " + $declared.Count)
Write-Host ("swift schemes:  " + $swiftSchemes.Count)
Write-Host ("swift bundles:  " + $swiftBundles.Count)

$missingInPlist = $swiftSchemes | Where-Object { $declared -notcontains $_ }
$missingInSwift = $declared | Where-Object { $swiftSchemes -notcontains $_ }
$dupSchemes = $declared | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }
$dupBundles = $swiftBundles | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }

$problems = @()
if ($declared.Count -gt 50) { $problems += "more than 50 declared schemes (Apple's canOpenURL limit)" }
if ($swiftSchemes.Count -ne $swiftBundles.Count) { $problems += 'candidate without scheme or bundle id' }
if ($missingInPlist) { $problems += ("scheme in Swift but not in Info.plist: " + ($missingInPlist -join ', ')) }
if ($missingInSwift) { $problems += ("scheme in Info.plist but not in Swift: " + ($missingInSwift -join ', ')) }
if ($dupSchemes) { $problems += ("duplicate schemes: " + ($dupSchemes -join ', ')) }
if ($dupBundles) { $problems += ("duplicate bundle ids: " + ($dupBundles -join ', ')) }

if ($problems.Count -eq 0) {
    Write-Host 'Scheme list: OK (Info.plist and AppSchemeProbe stay in sync)'
} else {
    $problems | ForEach-Object { Write-Host ('ERROR: ' + $_) }
    exit 1
}
