<#
.SYNOPSIS
    Cuts an app icon out of a screenshot (or any picture), resizes it and drops it into
    StorageInspector/Resources/AppIcons, so the app shows the real icon without any network.

.DESCRIPTION
    AppIconLoader prefers a bundled PNG over every other source: over the icon of the installed
    app and over the App Store artwork. A file here therefore works offline, on any iOS and in
    any build — exactly what a hand-made icon from your own screenshot needs.

    The picture is cropped to a square (centre crop unless -CropX/-CropY/-CropSize are given),
    resized to 180x180 px with a high quality filter and saved as PNG.

.PARAMETER Source
    Path of the picture to cut from (PNG, JPG, ...).

.PARAMETER Name
    File name without extension: `icon-youtube` (demo row id) or
    `icon-com.google.ios.youtube` (bundle id). Lowercase letters, digits, dots, dashes.

.PARAMETER CropX
    Left edge of the square to cut out, in pixels of the source picture.

.PARAMETER CropY
    Top edge of the square to cut out.

.PARAMETER CropSize
    Side length of the square to cut out. 0 (default) uses the shorter side of the picture.

.PARAMETER OutputSize
    Size of the written PNG in pixels. 180 (default) is 3x for the 62 pt tile.

.EXAMPLE
    ./tools/make-app-icon.ps1 -Source C:\icons\youtube.png -Name icon-youtube

.EXAMPLE
    ./tools/make-app-icon.ps1 -Source C:\icons\home-screen.png -Name icon-com.google.ios.youtube `
        -CropX 40 -CropY 300 -CropSize 512
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Name,
    [int]$CropX = -1,
    [int]$CropY = -1,
    [int]$CropSize = 0,
    [int]$OutputSize = 180
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if ($Name -notmatch '^[a-z0-9._-]+$') {
    throw "Name must be lowercase letters, digits, dots, dashes or underscores (got '$Name')."
}

$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$outDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\StorageInspector\Resources\AppIcons'))
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$image = [System.Drawing.Image]::FromFile($sourcePath)
try {
    $size = if ($CropSize -gt 0) { $CropSize } else { [Math]::Min($image.Width, $image.Height) }
    $left = if ($CropX -ge 0) { $CropX } else { [int](($image.Width - $size) / 2) }
    $top = if ($CropY -ge 0) { $CropY } else { [int](($image.Height - $size) / 2) }

    if ($left -lt 0 -or $top -lt 0 -or ($left + $size) -gt $image.Width -or ($top + $size) -gt $image.Height) {
        throw "Crop ${size}x${size} at (${left},${top}) does not fit into $($image.Width)x$($image.Height)."
    }

    $bitmap = New-Object System.Drawing.Bitmap -ArgumentList $OutputSize, $OutputSize
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.Clear([System.Drawing.Color]::Transparent)

        $targetRect = New-Object System.Drawing.Rectangle -ArgumentList 0, 0, $OutputSize, $OutputSize
        $sourceRect = New-Object System.Drawing.Rectangle -ArgumentList $left, $top, $size, $size
        $graphics.DrawImage($image, $targetRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
    } finally {
        $graphics.Dispose()
    }

    $targetPath = Join-Path $outDir "$Name.png"
    $bitmap.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
} finally {
    $image.Dispose()
}

Write-Output "Wrote $targetPath"
Write-Output 'Next: upload the PNG to GitHub (or rebuild locally) - AppIconLoader picks it up by itself.'
Write-Output 'No project.pbxproj change is needed: Resources/AppIcons is a folder reference.'
