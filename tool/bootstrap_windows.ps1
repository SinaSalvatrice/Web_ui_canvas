$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$temp = Join-Path $root ".flutter_host_scaffold"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter was not found in PATH."
}

if (Test-Path $temp) {
    Remove-Item $temp -Recurse -Force
}

flutter create --platforms=windows --org dev.sinasalvatrice --project-name web_ui_canvas $temp

$source = Join-Path $temp "windows"
$destination = Join-Path $root "windows"

if (-not (Test-Path $destination)) {
    Copy-Item $source $destination -Recurse
    Write-Host "Created Windows host."
} else {
    Write-Host "Windows host already exists - left untouched."
}

& (Join-Path $PSScriptRoot "apply_app_icon.ps1") -Letter W

Remove-Item $temp -Recurse -Force
Write-Host "Done. Run flutter pub get."
