param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("A", "W")]
    [string]$Letter
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Apply-AndroidIcon {
    $androidDir = Join-Path $root "android"
    if (-not (Test-Path $androidDir)) {
        return
    }

    $drawableDir = Join-Path $androidDir "app\src\main\res\drawable"
    New-Item -ItemType Directory -Path $drawableDir -Force | Out-Null

    $pathData = if ($Letter -eq "A") {
        "M18,90 L43,18 L65,18 L90,90 L72,90 L66,70 L42,70 L36,90 Z M47,55 L61,55 L54,33 Z"
    } else {
        "M13,22 L30,22 L39,72 L49,34 L59,34 L69,72 L78,22 L95,22 L81,90 L65,90 L54,51 L43,90 L27,90 Z"
    }

    $iconXml = @"
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape android:shape="rectangle">
            <gradient
                android:angle="135"
                android:startColor="#5B626D"
                android:centerColor="#303640"
                android:endColor="#12151A" />
            <corners android:radius="22dp" />
        </shape>
    </item>
    <item>
        <vector
            android:width="108dp"
            android:height="108dp"
            android:viewportWidth="108"
            android:viewportHeight="108">
            <path
                android:fillColor="#FFFFFFFF"
                android:pathData="$pathData" />
        </vector>
    </item>
</layer-list>
"@

    Write-Utf8NoBom -Path (Join-Path $drawableDir "app_icon.xml") -Content $iconXml

    $manifest = Join-Path $androidDir "app\src\main\AndroidManifest.xml"
    if (Test-Path $manifest) {
        $text = Get-Content $manifest -Raw
        $text = $text.Replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@drawable/app_icon"')
        $text = $text.Replace('android:icon="@drawable/app_icon"', 'android:icon="@drawable/app_icon"')
        Write-Utf8NoBom -Path $manifest -Content $text
    }

    Write-Host "Applied $Letter Android app icon."
}

function New-RoundedRectanglePath {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.RectangleF]$Rect,
        [Parameter(Mandatory = $true)][float]$Radius
    )

    $diameter = $Radius * 2
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddArc($Rect.X, $Rect.Y, $diameter, $diameter, 180, 90)
    $path.AddArc($Rect.Right - $diameter, $Rect.Y, $diameter, $diameter, 270, 90)
    $path.AddArc($Rect.Right - $diameter, $Rect.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Apply-WindowsIcon {
    $windowsDir = Join-Path $root "windows"
    if (-not (Test-Path $windowsDir)) {
        return
    }

    if (-not $IsWindows -and [System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
        Write-Host "Skipping Windows icon generation on non-Windows host."
        return
    }

    Add-Type -AssemblyName System.Drawing

    $size = 256
    $bitmap = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $rect = [System.Drawing.RectangleF]::new(3, 3, 250, 250)
    $path = New-RoundedRectanglePath -Rect $rect -Radius 42

    $start = [System.Drawing.Color]::FromArgb(255, 91, 98, 109)
    $finish = [System.Drawing.Color]::FromArgb(255, 18, 21, 26)
    $gradient = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $rect,
        $start,
        $finish,
        [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
    )
    $graphics.FillPath($gradient, $path)

    $border = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(90, 210, 215, 222), 2)
    $graphics.DrawPath($border, $path)

    $fontSize = if ($Letter -eq "A") { 166 } else { 152 }
    try {
        $font = [System.Drawing.Font]::new("Segoe UI", [single]$fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    } catch {
        $font = [System.Drawing.Font]::new("Arial", [single]$fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    }

    $format = [System.Drawing.StringFormat]::new()
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center

    $shadowBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(75, 0, 0, 0))
    $whiteBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 250, 251, 253))
    $textRectShadow = [System.Drawing.RectangleF]::new(2, 10, 256, 246)
    $textRect = [System.Drawing.RectangleF]::new(0, 7, 256, 246)
    $graphics.DrawString($Letter, $font, $shadowBrush, $textRectShadow, $format)
    $graphics.DrawString($Letter, $font, $whiteBrush, $textRect, $format)

    $iconPath = Join-Path $windowsDir "runner\resources\app_icon.ico"
    $iconDirectory = Split-Path -Parent $iconPath
    if (-not (Test-Path $iconDirectory)) {
        New-Item -ItemType Directory -Path $iconDirectory -Force | Out-Null
    }

    $handle = $bitmap.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($handle)
    $stream = [System.IO.File]::Open($iconPath, [System.IO.FileMode]::Create)
    try {
        $icon.Save($stream)
    } finally {
        $stream.Dispose()
        $icon.Dispose()
        $whiteBrush.Dispose()
        $shadowBrush.Dispose()
        $format.Dispose()
        $font.Dispose()
        $border.Dispose()
        $gradient.Dispose()
        $path.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
    }

    Write-Host "Applied $Letter Windows app icon."
}

Apply-AndroidIcon
Apply-WindowsIcon
