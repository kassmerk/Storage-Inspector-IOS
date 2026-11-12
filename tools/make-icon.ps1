# Generates the 1024x1024 app icon for Storage Inspector (no Photoshop / no Mac required).
# Usage: powershell -ExecutionPolicy Bypass -File tools\make-icon.ps1
param(
    [string]$Out = (Join-Path $PSScriptRoot '..\StorageInspector\Resources\Assets.xcassets\AppIcon.appiconset\AppIcon-1024.png')
)

Add-Type -AssemblyName System.Drawing

function New-RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

$size = 1024
$bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

# Background: deep indigo -> black diagonal gradient.
$rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
$c1 = [System.Drawing.Color]::FromArgb(255, 66, 58, 178)
$c2 = [System.Drawing.Color]::FromArgb(255, 10, 10, 14)
$bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, 55.0)
$g.FillRectangle($bgBrush, $rect)

# Inner dark card.
$cardPath = New-RoundRect 96 96 832 832 180
$cardBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 26, 26, 32))
$g.FillPath($cardBrush, $cardPath)

# Three ascending bars (storage bars).
$bars = @(
    @{ X = 232; H = 210; Color = [System.Drawing.Color]::FromArgb(255, 139, 135, 255) },
    @{ X = 452; H = 320; Color = [System.Drawing.Color]::FromArgb(255, 255, 122, 156) },
    @{ X = 672; H = 430; Color = [System.Drawing.Color]::FromArgb(255, 64, 200, 192) }
)

$bottom = 716
foreach ($bar in $bars) {
    $y = $bottom - $bar.H
    $p = New-RoundRect $bar.X $y 120 $bar.H 58
    $b = New-Object System.Drawing.SolidBrush $bar.Color
    $g.FillPath($b, $p)
    $b.Dispose()
    $p.Dispose()
}

# Track line under the bars.
$trackPath = New-RoundRect 232 772 560 34 17
$trackBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(90, 255, 255, 255))
$g.FillPath($trackBrush, $trackPath)

# Highlight on the track (the "used" part).
$fillPath = New-RoundRect 232 772 372 34 17
$fillBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 139, 135, 255))
$g.FillPath($fillBrush, $fillPath)

$dir = Split-Path -Parent $Out
if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)

$fillBrush.Dispose(); $trackBrush.Dispose(); $cardBrush.Dispose(); $bgBrush.Dispose()
$fillPath.Dispose(); $trackPath.Dispose(); $cardPath.Dispose()
$g.Dispose(); $bmp.Dispose()

Write-Host "Icon written to $Out"
