#!/usr/bin/env bash
# Copies Linux FFmpeg binaries from assets/bin/linux/ to the build output directory.
# Run after `flutter build linux` or `flutter run -d linux` to enable FFmpeg on Linux desktop.
set -e

CONFIG="${1:-Debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/assets/bin/linux"
DST="$ROOT/build/linux/x64/$CONFIG/bundle"

if [ ! -f "$SRC/ffmpeg" ]; then
  echo "ERROR: ffmpeg not found in $SRC."
  echo "Download a static Linux build from https://johnvansickle.com/ffmpeg/ and place ffmpeg + ffprobe there."
  exit 1
fi

if [ ! -d "$DST" ]; then
  echo "ERROR: Build output not found: $DST"
  echo "Run 'flutter build linux --${CONFIG,,}' first."
  exit 1
fi

cp "$SRC/ffmpeg"  "$DST/ffmpeg"
cp "$SRC/ffprobe" "$DST/ffprobe"
chmod +x "$DST/ffmpeg" "$DST/ffprobe"
echo "Copied ffmpeg + ffprobe to $DST"

if [ -f "$SRC/gifsicle" ]; then
  cp "$SRC/gifsicle" "$DST/gifsicle"
  chmod +x "$DST/gifsicle"
  echo "Copied gifsicle to $DST"
fi
