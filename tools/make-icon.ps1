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
# The artwork is the reference design of 1.4: a diagonal two-tone gradient (bright top-left, a
# darker sweep over the lower-right half) and the white "storage tag" glyph — a rounded cap over a
# capsule whose hole is punched through, so the gradient shows inside it. The orange variant is the
# primary icon. Drop your own 1024x1024 artwork into AppIconVariants using the same file names to
# replace the generated ones — the packaging step (tools\build-ipa.sh / the GitHub workflow) picks
# them up automatically.
param(
    [string]$VariantDir = (Join-Path $PSScriptRoot '..\StorageInspector\Resources\AppIconVariants'),
    [string]$PrimaryOut = (Join-Path $PSScriptRoot '..\StorageInspector\Resources\Assets.xcassets\AppIcon.appiconset\AppIcon-1024.png')
)

Add-Type -AssemblyName System.Drawing

$IconSize = 1024

function New-RoundRect([double]$x, [double]$y, [double]$w, [double]$h, [double]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc([single]$x, [single]$y, [single]$d, [single]$d, 180, 90)
    $path.AddArc([single]($x + $w - $d), [single]$y, [single]$d, [single]$d, 270, 90)
    $path.AddArc([single]($x + $w - $d), [single]($y + $h - $d), [single]$d, [single]$d, 0, 90)
    $path.AddArc([single]$x, [single]($y + $h - $d), [single]$d, [single]$d, 90, 90)
    $path.CloseFigure()
    return $path
}

# The white "storage tag": a rounded cap, a wide capsule under it, and a hole in the capsule.
#
# The three shapes go into one path with the *alternate* fill mode: the hole is a separate figure
# inside the capsule, so filling it once leaves the background visible inside the hole instead of
# painting it a second time (which never matched the gradient exactly).
function New-Glyph([double]$s) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.FillMode = [System.Drawing.Drawing2D.FillMode]::Alternate

    # Cap: narrow at the top with rounded corners, flaring to the bottom edge.
    $path.StartFigure()
    $path.AddLine([single]($s * 0.283), [single]($s * 0.472), [single]($s * 0.372), [single]($s * 0.331))
    $path.AddBezier(
        [single]($s * 0.372), [single]($s * 0.331),
        [single]($s * 0.380), [single]($s * 0.313),
        [single]($s * 0.394), [single]($s * 0.302),
        [single]($s * 0.414), [single]($s * 0.302)
    )
    $path.AddLine([single]($s * 0.414), [single]($s * 0.302), [single]($s * 0.586), [single]($s * 0.302))
    $path.AddBezier(
        [single]($s * 0.586), [single]($s * 0.302),
        [single]($s * 0.606), [single]($s * 0.302),
        [single]($s * 0.620), [single]($s * 0.313),
        [single]($s * 0.628), [single]($s * 0.331)
    )
    $path.AddLine([single]($s * 0.628), [single]($s * 0.331), [single]($s * 0.717), [single]($s * 0.472))
    $path.CloseFigure()

    # Capsule, wider than the cap so its ends stick out on both sides.
    $capsuleHeight = $s * 0.156
    $capsule = New-RoundRect ($s * 0.255) ($s * 0.494) ($s * 0.490) $capsuleHeight ($capsuleHeight / 2)
    $path.AddPath($capsule, $false)
    $capsule.Dispose()

    # The hole: one more figure inside the capsule, punched out by the alternate fill.
    $hole = $s * 0.086
    $path.AddEllipse(
        [single](($s * 0.655) - ($hole / 2)),
        [single](($s * 0.572) - ($hole / 2)),
        [single]$hole,
        [single]$hole
    )

    return $path
}

function New-Icon([string]$Path, [int]$R1, [int]$G1, [int]$B1, [int]$R2, [int]$G2, [int]$B2) {
    $bmp = New-Object System.Drawing.Bitmap($IconSize, $IconSize, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    $rect = New-Object System.Drawing.Rectangle(0, 0, $IconSize, $IconSize)

    # Base: diagonal gradient, brightest in the top-left corner.
    $from = [System.Drawing.Color]::FromArgb(255, $R1, $G1, $B1)
    $to = [System.Drawing.Color]::FromArgb(255, $R2, $G2, $B2)
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $from, $to, 45.0)
    $g.FillRectangle($bgBrush, $rect)

    # The diagonal sweep: a straight edge from the top-right corner to the bottom-left one, with
    # the lower-right half pushed darker. That two-tone cut is what makes the tile read as an icon
    # instead of a plain gradient.
    $sweep = New-Object System.Drawing.Drawing2D.GraphicsPath
    $points = [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF([single]$IconSize, [single]0)),
        (New-Object System.Drawing.PointF([single]$IconSize, [single]$IconSize)),
        (New-Object System.Drawing.PointF([single]0, [single]$IconSize))
    )
    $sweep.AddPolygon($points)
    $sweepBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(64, 0, 0, 0))
    $g.FillPath($sweepBrush, $sweep)

    $glyph = New-Glyph $IconSize

    # Soft shadow first, so the white shape sits on the gradient instead of floating on it. The
    # shadow is the same path filled a few times with a growing offset and a low alpha: that reads
    # as a blur without needing a bitmap filter.
    for ($step = 0; $step -lt 6; $step++) {
        $alpha = 12
        $offsetY = [single]($IconSize * (0.006 + $step * 0.0035))
        $offsetX = [single]($IconSize * (0.001 + $step * 0.001))
        $shadowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($alpha, 0, 0, 0))
        $g.TranslateTransform($offsetX, $offsetY)
        $g.FillPath($shadowBrush, $glyph)
        $g.ResetTransform()
        $shadowBrush.Dispose()
    }

    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $g.FillPath($white, $glyph)

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)

    $white.Dispose()
    $glyph.Dispose()
    $sweepBrush.Dispose()
    $sweep.Dispose()
    $bgBrush.Dispose()
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Icon written to $Path"
}


$variants = @(
    @{ Name = 'icon-orange';   From = @(255, 146, 22);  To = @(240, 52, 8) },
    @{ Name = 'icon-indigo';   From = @(128, 124, 244); To = @(78, 74, 214) },
    @{ Name = 'icon-graphite'; From = @(60, 60, 63);    To = @(8, 8, 10) },
    @{ Name = 'icon-crimson';  From = @(178, 10, 26);   To = @(16, 3, 6) }
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

