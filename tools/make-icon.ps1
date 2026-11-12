# Generates the 1024x1024 app icon set for Storage Inspector (no Photoshop / no Mac required).
#
#   powershell -ExecutionPolicy Bypass -File tools\make-icon.ps1
#
# Writes:
#   StorageInspector\Resources\Assets.xcassets\AppIcon.appiconset\AppIcon-1024.png  (primary icon)
#   StorageInspector\Resources\AppIconVariants\icon-orange.png                     ("App Icon" picker)
#   StorageInspector\Resources\AppIconVariants\icon-indigo.png
#   StorageInspector\Resources\AppIconVariants\icon-graphite.png
#   StorageInspector\Resources\AppIconVariants\icon-crimson.png
#
# The orange variant is the default icon. Drop your own 1024x1024 artwork into
# AppIconVariants using the same file names to replace the generated placeholders — the
# packaging script (tools\build-ipa.sh / the GitHub workflow) picks them up automatically.
param(
    [string]$VariantDir = (Join-Path $PSScriptRoot '..\StorageInspector\Resources\AppIconVariants'),
    [string]$PrimaryOut = (Join-Path $PSScriptRoot '..\StorageInspector\Resources\Assets.xcassets\AppIcon.appiconset\AppIcon-1024.png')
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

# White "storage tag" glyph: rounded roof + capsule, with a hole punched by re-filling it
# with the background gradient brush (so the result has no alpha channel at all).
function Add-Glyph($g, $bgBrush) {
    $s = 1024
    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)

    $roof = New-Object System.Drawing.Drawing2D.GraphicsPath
    $roof.StartFigure()
    $roof.AddLine($s * 0.255, $s * 0.468, $s * 0.318, $s * 0.332)
    $roof.AddBezier($s * 0.318, $s * 0.332, $s * 0.322, $s * 0.300, $s * 0.352, $s * 0.300, $s * 0.378, $s * 0.300)
    $roof.AddLine($s * 0.378, $s * 0.300, $s * 0.622, $s * 0.300)
    $roof.AddBezier($s * 0.622, $s * 0.300, $s * 0.648, $s * 0.300, $s * 0.678, $s * 0.300, $s * 0.682, $s * 0.332)
    $roof.AddLine($s * 0.682, $s * 0.332, $s * 0.745, $s * 0.468)
    $roof.CloseFigure()
    $g.FillPath($white, $roof)

    $capW = $s * 0.490
    $capH = $s * 0.185
    $cap = New-RoundRect ($s * 0.255) ($s * 0.4855) $capW $capH ($capH / 2)
    $g.FillPath($white, $cap)

    $hole = $s * 0.076
    $g.FillEllipse($bgBrush, ($s * 0.632 - $hole / 2), ($s * 0.578 - $hole / 2), $hole, $hole)

    $cap.Dispose()
    $roof.Dispose()
    $white.Dispose()
}

function New-Icon([string]$Path, [int]$R1, [int]$G1, [int]$B1, [int]$R2, [int]$G2, [int]$B2) {
    $size = 1024
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    # Diagonal gradient background.
    $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
    $c1 = [System.Drawing.Color]::FromArgb(255, $R1, $G1, $B1)
    $c2 = [System.Drawing.Color]::FromArgb(255, $R2, $G2, $B2)
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, 45.0)
    $g.FillRectangle($bgBrush, $rect)

    Add-Glyph $g $bgBrush

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)

    $bgBrush.Dispose()
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Icon written to $Path"
}

$variants = @(
    @{ Name = 'icon-orange';   From = @(255, 163, 32);  To = @(255, 74, 0) },
    @{ Name = 'icon-indigo';   From = @(124, 121, 242); To = @(91, 87, 224) },
    @{ Name = 'icon-graphite'; From = @(46, 46, 49);    To = @(10, 10, 12) },
    @{ Name = 'icon-crimson';  From = @(174, 0, 22);    To = @(20, 6, 8) }
)

foreach ($variant in $variants) {
    $path = Join-Path $VariantDir ($variant.Name + '.png')
    New-Icon $path $variant.From[0] $variant.From[1] $variant.From[2] $variant.To[0] $variant.To[1] $variant.To[2]
}

# The primary icon in the asset catalogue is the orange one.
$orange = Join-Path $VariantDir 'icon-orange.png'
$primaryDir = Split-Path -Parent $PrimaryOut
if (-not (Test-Path -LiteralPath $primaryDir)) {
    New-Item -ItemType Directory -Path $primaryDir -Force | Out-Null
}
Copy-Item -LiteralPath $orange -Destination $PrimaryOut -Force
Write-Host "Primary AppIcon updated: $PrimaryOut"
