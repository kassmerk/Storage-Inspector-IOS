# Lightweight sanity check for the Swift sources: balanced braces / parens / brackets
# per file. It is not a compiler, but it catches truncated or mangled files.
param(
    [string]$Root = (Join-Path $PSScriptRoot '..\StorageInspector')
)

$files = Get-ChildItem -LiteralPath $Root -Recurse -Filter *.swift
$errors = @()

foreach ($file in $files) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    $pairs = @(
        @{ Open = '{'; Close = '}' },
        @{ Open = '('; Close = ')' },
        @{ Open = '['; Close = ']' }
    )

    foreach ($pair in $pairs) {
        $o = ([regex]::Matches($text, [regex]::Escape($pair.Open))).Count
        $c = ([regex]::Matches($text, [regex]::Escape($pair.Close))).Count
        if ($o -ne $c) {
            $errors += ("{0}: '{1}' vs '{2}' ({3} vs {4})" -f $file.Name, $pair.Open, $pair.Close, $o, $c)
        }
    }

    if ($text -match '#Preview') {
        $errors += ("{0}: still contains a #Preview macro (needs Xcode 15+)" -f $file.Name)
    }
}

Write-Host ("Checked {0} Swift files" -f $files.Count)
if ($errors.Count -eq 0) {
    Write-Host "Swift sources: OK"
} else {
    $errors | ForEach-Object { Write-Host ("ERROR: " + $_) }
    exit 1
}
