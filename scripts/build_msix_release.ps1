# Full release MSIX build pipeline.
#
# Usage:
#   scripts\build_msix_release.ps1                  # build + package (no signing)
#   scripts\build_msix_release.ps1 -Sign            # build + self-sign (sideload/testing)
#   scripts\build_msix_release.ps1 -CertPath my.pfx -CertPassword pass  # use existing cert
#
# For Microsoft Store submission: run without -Sign.
# Upload the unsigned .msix from build\windows\x64\runner\Release\ to Partner Center.
# Partner Center handles signing.
#
# For sideload (self-signed): run with -Sign.
# Recipient must: (1) install the .cer, (2) enable Developer Mode or sideloading.
#
# GPL release checklist (PLAN.md §5) -- verify before every release that bundles
# assets/bin/windows/ FFmpeg binaries:
#   [ ] Repo is public with a GPL-compatible LICENSE committed (hard gate).
#   [ ] About-screen "Open-source licenses" section (assets/licenses/*.txt) is
#       present and matches the actually-bundled FFmpeg build.
#   [ ] FFMPEG_NOTICE.txt's corresponding-source pointer matches this release's
#       FFmpeg version/tag (currently n6.0) and this repo's tag/commit.
#   [ ] Bundled DLLs (avcodec/avformat/.../libx264/libvpx/libaom/libopus/
#       libwinpthread/libfreetype + its harfbuzz/glib/png/zlib/brotli/pcre2/
#       iconv chain -- see scripts/setup_windows_dev.ps1's $required list)
#       are the versions actually built by scripts/build_ffmpeg_shim.ps1 for
#       this release, not stale dev-machine copies.

param(
    [switch]$Sign,
    [string]$CertPath = '',
    [string]$CertPassword = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

# ── 1. Build ────────────────────────────────────────────────────────────────
Write-Host "[1/3] Building Flutter Windows release..." -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# ── 2. Bundle FFmpeg binaries ────────────────────────────────────────────────
Write-Host "[2/3] Copying FFmpeg binaries to release output..." -ForegroundColor Cyan
& "$PSScriptRoot\setup_windows_dev.ps1" -Config Release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# ── 3. Package MSIX ─────────────────────────────────────────────────────────
Write-Host "[3/3] Creating MSIX package..." -ForegroundColor Cyan

if ($Sign) {
    if ($CertPath -eq '') {
        # Auto-generate a self-signed cert for dev/sideload testing.
        # Requires running as Administrator (New-SelfSignedCertificate needs cert store access).
        $devCertPassword = 'devcert'
        $devCertPath = Join-Path $root 'build\gifolomora_dev.pfx'
        $devCerPath  = Join-Path $root 'build\gifolomora_dev.cer'

        Write-Host "  Generating self-signed certificate..." -ForegroundColor Yellow
        $cert = New-SelfSignedCertificate `
            -Type Custom `
            -Subject 'CN=Takayoshi Code' `
            -KeyUsage DigitalSignature `
            -FriendlyName 'Gifolomora Dev Cert' `
            -CertStoreLocation 'Cert:\CurrentUser\My' `
            -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}')

        $securePass = ConvertTo-SecureString -String $devCertPassword -Force -AsPlainText
        Export-PfxCertificate -Cert $cert -FilePath $devCertPath -Password $securePass | Out-Null
        Export-Certificate -Cert $cert -FilePath $devCerPath | Out-Null
        Write-Host "  Self-signed cert exported to: $devCertPath" -ForegroundColor Yellow
        Write-Host "  Public cert for distribution: $devCerPath" -ForegroundColor Yellow
        Write-Host "  Sideload recipients must install $devCerPath into 'Trusted People'." -ForegroundColor Yellow

        $CertPath     = $devCertPath
        $CertPassword = $devCertPassword
    }

    dart run msix:create --certificate-path "$CertPath" --certificate-password "$CertPassword"
} else {
    # No signing — suitable for Store submission via Partner Center
    dart run msix:create
}

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$msixPath = Join-Path $root "build\windows\x64\runner\Release\gifolomora.msix"
if (Test-Path $msixPath) {
    Write-Host ""
    Write-Host "MSIX ready: $msixPath" -ForegroundColor Green
} else {
    Write-Warning "MSIX file not found at expected path. Check dart run msix:create output above."
}
