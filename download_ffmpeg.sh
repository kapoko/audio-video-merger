#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="$SCRIPT_DIR/Resources"
TMP_DIR="$RESOURCES_DIR/.ffmpeg_tmp"
VERSION_FILE="$RESOURCES_DIR/.ffmpeg_source_urls"

INTEL_URL="https://www.osxexperts.net/ffmpeg80intel.zip"
ARM_URL="https://www.osxexperts.net/ffmpeg81arm.zip"

INTEL_ZIP="$TMP_DIR/ffmpeg-intel.zip"
ARM_ZIP="$TMP_DIR/ffmpeg-arm64.zip"

INTEL_OUT="$RESOURCES_DIR/ffmpeg-x86_64"
ARM_OUT="$RESOURCES_DIR/ffmpeg-arm64"
CURRENT_SOURCE_TAG="intel=${INTEL_URL};arm=${ARM_URL}"

is_binary_valid() {
    local binary_path="$1"
    local expected_arch="$2"

    if [ ! -x "$binary_path" ]; then
        return 1
    fi

    local info
    info="$(file "$binary_path" 2>/dev/null || true)"
    case "$info" in
        *"$expected_arch"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

if [ -f "$VERSION_FILE" ] \
    && [ "$(cat "$VERSION_FILE")" = "$CURRENT_SOURCE_TAG" ] \
    && is_binary_valid "$INTEL_OUT" "x86_64" \
    && is_binary_valid "$ARM_OUT" "arm64"
then
    echo "FFmpeg binaries already present and up to date. Skipping download."
    echo "- Intel: $INTEL_OUT"
    echo "- ARM64: $ARM_OUT"
    exit 0
fi

if [ ! -f "$VERSION_FILE" ] \
    && is_binary_valid "$INTEL_OUT" "x86_64" \
    && is_binary_valid "$ARM_OUT" "arm64"
then
    printf '%s\n' "$CURRENT_SOURCE_TAG" >"$VERSION_FILE"
    echo "FFmpeg binaries found and validated. Saved source tag and skipping download."
    echo "- Intel: $INTEL_OUT"
    echo "- ARM64: $ARM_OUT"
    exit 0
fi

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
printf '%s\n' "$CURRENT_SOURCE_TAG" >"$VERSION_FILE"
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
