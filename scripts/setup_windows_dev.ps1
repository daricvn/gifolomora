# Copies Windows FFmpeg binaries from assets/bin/windows/ to the build output directory.
# Run after `flutter build windows` or `flutter run -d windows` to enable FFmpeg on Windows desktop.
param(
    [ValidateSet('Debug','Profile','Release')]
    [string]$Config = 'Debug'
)

$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root "assets\bin\windows"
$dst = Join-Path $root "build\windows\x64\runner\$Config"

if (-not (Test-Path $src\ffmpeg.exe)) {
    Write-Error "ffmpeg.exe not found in $src. Download it from https://www.gyan.dev/ffmpeg/builds/ and place ffmpeg.exe + ffprobe.exe there."
    exit 1
}
if (-not (Test-Path $dst)) {
    Write-Error "Build output not found: $dst. Run 'flutter build windows --$($Config.ToLower())' first."
    exit 1
}

Copy-Item "$src\ffmpeg.exe"  $dst -Force
Copy-Item "$src\ffprobe.exe" $dst -Force
Write-Output "Copied ffmpeg.exe + ffprobe.exe to $dst"
