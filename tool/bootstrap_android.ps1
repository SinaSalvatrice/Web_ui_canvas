$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$androidDir = Join-Path $repoRoot "android"

$hostExists = Test-Path $androidDir
if ($hostExists) {
    Write-Host "Android host already exists: $androidDir"
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter was not found in PATH."
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("web_ui_canvas_android_" + [Guid]::NewGuid().ToString("N"))

try {
    if (-not $hostExists) {
        Write-Host "Generating lightweight Android host..."
        & flutter create --platforms=android --project-name web_ui_canvas --org de.circuitcurios $tempRoot
        if ($LASTEXITCODE -ne 0) {
            throw "flutter create failed with exit code $LASTEXITCODE"
        }

        Copy-Item (Join-Path $tempRoot "android") $androidDir -Recurse -Force
        Write-Host "Android host generated."
    }

    $manifest = Join-Path $androidDir "app\src\main\AndroidManifest.xml"
    if (Test-Path $manifest) {
        $text = Get-Content $manifest -Raw
        $text = $text.Replace('android:label="web_ui_canvas"', 'android:label="Web UI Canvas"')
        Set-Content -Path $manifest -Value $text -NoNewline
    }

    & (Join-Path $PSScriptRoot "apply_app_icon.ps1") -Letter W
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
