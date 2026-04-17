#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="$SCRIPT_DIR/Resources"
TMP_DIR="$RESOURCES_DIR/.ffmpeg_tmp"

INTEL_URL="https://www.osxexperts.net/ffmpeg80intel.zip"
ARM_URL="https://www.osxexperts.net/ffmpeg81arm.zip"

INTEL_ZIP="$TMP_DIR/ffmpeg-intel.zip"
ARM_ZIP="$TMP_DIR/ffmpeg-arm64.zip"

INTEL_OUT="$RESOURCES_DIR/ffmpeg-x86_64"
ARM_OUT="$RESOURCES_DIR/ffmpeg-arm64"

echo "Preparing Resources directory..."
mkdir -p "$RESOURCES_DIR"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR/intel" "$TMP_DIR/arm64"

echo "Downloading Intel FFmpeg from osxexperts..."
curl -fsSL "$INTEL_URL" -o "$INTEL_ZIP"

echo "Downloading Apple Silicon FFmpeg from osxexperts..."
curl -fsSL "$ARM_URL" -o "$ARM_ZIP"

echo "Extracting Intel FFmpeg..."
unzip -o "$INTEL_ZIP" -d "$TMP_DIR/intel" >/dev/null

echo "Extracting Apple Silicon FFmpeg..."
unzip -o "$ARM_ZIP" -d "$TMP_DIR/arm64" >/dev/null

if [ ! -f "$TMP_DIR/intel/ffmpeg" ]; then
    echo "Intel ffmpeg binary not found in archive"
    exit 1
fi

if [ ! -f "$TMP_DIR/arm64/ffmpeg" ]; then
    echo "ARM ffmpeg binary not found in archive"
    exit 1
fi

cp "$TMP_DIR/intel/ffmpeg" "$INTEL_OUT"
cp "$TMP_DIR/arm64/ffmpeg" "$ARM_OUT"

chmod +x "$INTEL_OUT" "$ARM_OUT"
rm -rf "$TMP_DIR"

echo "FFmpeg binaries downloaded successfully"
echo "- Intel: $INTEL_OUT"
echo "- ARM64: $ARM_OUT"

echo "Verifying binary architectures..."
INTEL_FILE_INFO="$(file "$INTEL_OUT")"
ARM_FILE_INFO="$(file "$ARM_OUT")"

echo "$INTEL_FILE_INFO"
echo "$ARM_FILE_INFO"

case "$INTEL_FILE_INFO" in
    *x86_64*)
        echo "Intel binary architecture check passed"
        ;;
    *)
        echo "Warning: Intel binary does not appear to be x86_64"
        ;;
esac

case "$ARM_FILE_INFO" in
    *arm64*)
        echo "ARM64 binary architecture check passed"
        ;;
    *)
        echo "Warning: ARM binary does not appear to be arm64"
        ;;
esac
