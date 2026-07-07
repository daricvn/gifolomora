# Copies Windows FFmpeg binaries from assets/bin/windows/ to the build output directory.
# Run after `flutter build windows` or `flutter run -d windows` to enable FFmpeg on Windows desktop.
#
# assets/bin/windows/ is git-ignored, same as it always was -- devs get this
# file set from the release bundle (or by running scripts/build_ffmpeg_shim.ps1
# plus a GPL FFmpeg build of their own), not from git.
#
# All-in on the DLL backend (PLAN.md §9 decision #2): there is no ffmpeg.exe
# bundled anymore. gm_shim.dll + its companion DLLs are the only way FFmpeg
# works on Windows now -- both exports (FfmpegDllBackend) and the screen
# recorder (ScreenRecorderService's RecorderEngine) run through it. Missing
# any of these means no FFmpeg on Windows at all, not a silent exe fallback.
param(
    [ValidateSet('Debug','Profile','Release')]
    [string]$Config = 'Debug'
)

$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root "assets\bin\windows"
$dst = Join-Path $root "build\windows\x64\runner\$Config"

$required = @(
    'gm_shim.dll',
    'avcodec-60.dll', 'avdevice-60.dll', 'avfilter-9.dll', 'avformat-60.dll',
    'avutil-58.dll', 'swresample-4.dll', 'swscale-7.dll',
    'libx264-165.dll', 'libvpx-1.dll', 'libaom.dll', 'libopus-0.dll',
    'libwinpthread-1.dll',
    # hard (non-delay) import-table deps of the libs above -- LoadLibrary fails
    # the whole gm_shim.dll load (error 126, "module not found") if any is
    # missing, even though the app never calls into them: postproc-57.dll is
    # libpostproc (built alongside avcodec/avformat since --enable-gpl doesn't
    # disable it by default, avfilter's `pp` filter links it), SDL2.dll/
    # libva.dll are avdevice/avcodec's compiled-in (unused) SDL2 output device
    # and VAAPI hwaccel probe, liblzma-5.dll is avcodec's lzma decompress dep.
    'postproc-57.dll', 'SDL2.dll', 'libva.dll', 'liblzma-5.dll',
    # drawtext filter's libfreetype dependency chain (--enable-libfreetype,
    # PLAN.md §6) -- without these, every text-overlay job fails with
    # "No such filter: 'drawtext'" (rc=1).
    'libfreetype-6.dll', 'libharfbuzz-0.dll', 'libpng16-16.dll', 'zlib1.dll',
    'libbz2-1.dll', 'libbrotlidec.dll', 'libbrotlicommon.dll',
    'libglib-2.0-0.dll', 'libgraphite2.dll', 'libc++.dll', 'libintl-8.dll',
    'libpcre2-8-0.dll', 'libiconv-2.dll'
)

$missing = $required | Where-Object { -not (Test-Path (Join-Path $src $_)) }
if ($missing.Count -gt 0) {
    Write-Error "Missing from $src : $($missing -join ', '). See PLAN.md §6 for the file list and scripts/build_ffmpeg_shim.ps1 for building gm_shim.dll."
    exit 1
}
if (-not (Test-Path $dst)) {
    Write-Error "Build output not found: $dst. Run 'flutter build windows --$($Config.ToLower())' first."
    exit 1
}

foreach ($name in $required) {
    Copy-Item (Join-Path $src $name) $dst -Force
}
Write-Output "Copied: $($required -join ', ')"
