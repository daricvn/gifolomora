# Builds windows/ffmpeg_shim/gm_shim.dll from source.
#
# Requires MSYS2 with the CLANG64 environment (mingw-w64-clang-x86_64-toolchain,
# -nasm) and an FFmpeg 6.0 dev tree (headers + libavformat.dll.a etc, plus the
# FFmpeg source checkout itself for internal headers like libavutil/internal.h
# and the generated config.h).
#
# Why clang and not gcc: the MSYS2 mingw-w64-x86_64-gcc toolchain was tried
# first and hit a reproducible GCC codegen bug ("operand type mismatch for
# `shr`") across many unrelated libavformat/libavcodec files -- not something
# to patch around file-by-file. clang built FFmpeg 6.0 clean with zero errors.
# Bonus: clang supports real __try/__except if a future revision wants that
# instead of the AddVectoredExceptionHandler+longjmp guard gm_shim.c uses now.
#
# Usage:
#   .\scripts\build_ffmpeg_shim.ps1 -FfmpegBuildDir C:\path\to\ffmpeg-n6.0-build -FfmpegSrcDir C:\path\to\ffmpeg-src
#
#   Add -BuildFFmpeg to also run FFmpeg's own configure/make/install into
#   -FfmpegBuildDir first (GPLv3 flags per ARCHITECTURE.md, overridable via
#   -ConfigureFlags), for a from-scratch build instead of relinking against
#   libs you already built yourself.

param(
    [Parameter(Mandatory = $true)][string]$FfmpegBuildDir,
    [Parameter(Mandatory = $true)][string]$FfmpegSrcDir,
    [string]$Msys2Root = "C:\msys64",
    [string]$OutDir = "$PSScriptRoot\..\windows\ffmpeg_shim",
    # Runs FFmpeg's own ./configure + make + make install into $FfmpegBuildDir
    # before linking the shim. Off by default -- most shim-only iterations
    # (editing gm_shim.c) just relink against an already-built FfmpegBuildDir;
    # forcing a full FFmpeg rebuild every time would cost minutes for nothing.
    [switch]$BuildFFmpeg,
    # GPLv3 feature set (ARCHITECTURE.md's "gm_shim.dll" section) -- keep this
    # array in sync with that doc; it's the single source of truth for which
    # codecs/filters are compiled in. Missing one here means a codec/filter
    # silently isn't there at runtime (rc=1, not a build error) -- see
    # ARCHITECTURE.md's "Build-config gaps bite silently" note.
    [string[]]$ConfigureFlags = @(
        "--enable-gpl", "--enable-version3",
        "--enable-libx264", "--enable-libvpx", "--enable-libaom", "--enable-libopus",
        "--enable-libfreetype", "--enable-zlib",
        "--enable-avdevice", "--enable-ffmpeg"
    )
)

$ErrorActionPreference = "Stop"

$bash = Join-Path $Msys2Root "usr\bin\bash.exe"
if (-not (Test-Path $bash)) {
    throw "MSYS2 bash not found at $bash. Install MSYS2 first (https://www.msys2.org/)."
}

if ($BuildFFmpeg) {
    if (-not (Test-Path $FfmpegBuildDir)) {
        New-Item -ItemType Directory -Force -Path $FfmpegBuildDir | Out-Null
    }
    $srcDirForConfigure = Resolve-Path $FfmpegSrcDir
    $prefixDir = (Resolve-Path $FfmpegBuildDir) -replace '^([A-Za-z]):', '/$1' -replace '\\', '/'
    $flagsJoined = $ConfigureFlags -join ' '
    $configureCmd = @"
set -e
cd '$srcDirForConfigure'
# distclean first -- stale .o from a prior configure can survive a flag
# change (e.g. png encoder missing at runtime despite --enable-zlib in the
# printed config string); || true covers a never-configured checkout.
make distclean >/dev/null 2>&1 || true
./configure --target-os=mingw32 --arch=x86_64 --cc=clang \
  --enable-shared --disable-static \
  $flagsJoined \
  --pkg-config=pkgconf \
  --prefix='$prefixDir'
make -j`$(nproc)
make install
"@
    $env:MSYSTEM = "CLANG64"
    & $bash -lc $configureCmd
    if ($LASTEXITCODE -ne 0) {
        throw "FFmpeg configure/build failed (exit $LASTEXITCODE)"
    }
}

$shimDir = Resolve-Path $OutDir
$buildDir = Resolve-Path $FfmpegBuildDir
$srcDir = Resolve-Path $FfmpegSrcDir

# Paths are handed to bash, which needs /c/... style; MSYS2 bash also accepts
# the native form for -I/-L arguments, so no conversion needed here.
$cmd = @"
set -e
clang -shared -O1 -std=gnu11 -Wno-everything \
  -I'$srcDir' -I'$buildDir/include' \
  '$shimDir'/fftools/*.c '$shimDir'/gm_shim.c \
  -L'$buildDir/lib' -lavformat -lavcodec -lavutil -lavfilter -lavdevice -lswscale -lswresample \
  -lbcrypt -lole32 -luuid -lstrmiids -lsecur32 \
  -o '$shimDir/gm_shim.dll' -Wl,--out-implib,'$shimDir/gm_shim.lib'
"@

$env:MSYSTEM = "CLANG64"
& $bash -lc $cmd
if ($LASTEXITCODE -ne 0) {
    throw "gm_shim.dll build failed (exit $LASTEXITCODE)"
}

Write-Host "Built $shimDir\gm_shim.dll"

# assets/bin/windows is what the app actually loads at runtime
# (setup_windows_dev.ps1 copies from there, not from $OutDir) -- without this
# sync a rebuilt gm_shim.dll never reaches the app, and avcodec-60.dll etc
# (which carry any --enable-* flag change, e.g. the zlib/png-encoder fix)
# stay stale even though gm_shim.dll itself looks freshly built.
$assetsDir = Resolve-Path (Join-Path $PSScriptRoot "..\assets\bin\windows") -ErrorAction SilentlyContinue
if ($assetsDir) {
    Copy-Item "$shimDir\gm_shim.dll" $assetsDir -Force
    $avLibs = @('avcodec-60.dll', 'avdevice-60.dll', 'avfilter-9.dll',
        'avformat-60.dll', 'avutil-58.dll', 'swresample-4.dll', 'swscale-7.dll',
        # hard (non-delay) import-table deps of the libs above -- missing any
        # one fails gm_shim.dll's LoadLibrary entirely (error 126), even
        # though nothing in the app calls into them: postproc-57.dll is
        # avfilter's `pp` filter dep (libpostproc builds automatically once
        # --enable-gpl is set), SDL2.dll/libva.dll are avdevice/avcodec's
        # compiled-in SDL2 output device + VAAPI hwaccel probe, liblzma-5.dll
        # is avcodec's lzma decompress dep.
        'postproc-57.dll')
    foreach ($name in $avLibs) {
        $built = Join-Path $buildDir "bin\$name"
        if (Test-Path $built) { Copy-Item $built $assetsDir -Force }
    }
    # SDL2.dll/libva.dll/liblzma-5.dll aren't produced by the FFmpeg build
    # itself -- they're MSYS2 packages avdevice/avcodec link against, so they
    # live in the toolchain's own bin dir, not $buildDir\bin.
    $msys2Bin = Join-Path $Msys2Root "clang64\bin"
    foreach ($name in @('SDL2.dll', 'libva.dll', 'liblzma-5.dll')) {
        $built = Join-Path $msys2Bin $name
        if (Test-Path $built) { Copy-Item $built $assetsDir -Force }
    }
    Write-Host "Synced gm_shim.dll + rebuilt FFmpeg libs to $assetsDir"
} else {
    Write-Warning "assets\bin\windows not found -- copy gm_shim.dll and the av*.dll libs there manually (see setup_windows_dev.ps1)."
}
