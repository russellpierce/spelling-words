#!/bin/bash
# Install FFmpeg Static Build (no sudo required)
# Downloads John Van Sickle's static build for Linux

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="$PROJECT_DIR/bin"

echo "======================================"
echo "FFmpeg Static Build Installer"
echo "======================================"
echo ""

# Create bin directory
mkdir -p "$INSTALL_DIR"

# Download URL for latest git build (recommended)
FFMPEG_URL="https://johnvansickle.com/ffmpeg/builds/ffmpeg-git-amd64-static.tar.xz"
FFMPEG_MD5_URL="https://johnvansickle.com/ffmpeg/builds/ffmpeg-git-amd64-static.tar.xz.md5"

echo "Downloading FFmpeg static build..."
cd "$INSTALL_DIR"

# Download ffmpeg
if command -v wget &> /dev/null; then
    wget -q --show-progress "$FFMPEG_URL" -O ffmpeg-static.tar.xz
    wget -q "$FFMPEG_MD5_URL" -O ffmpeg-static.tar.xz.md5
elif command -v curl &> /dev/null; then
    curl -L -o ffmpeg-static.tar.xz "$FFMPEG_URL"
    curl -L -o ffmpeg-static.tar.xz.md5 "$FFMPEG_MD5_URL"
else
    echo "❌ ERROR: Neither wget nor curl is available. Please install one of them."
    exit 1
fi

echo ""
echo "Verifying download integrity..."
md5sum -c ffmpeg-static.tar.xz.md5

echo ""
echo "Extracting FFmpeg..."
tar xf ffmpeg-static.tar.xz --strip-components=1

# Clean up archive
rm -f ffmpeg-static.tar.xz ffmpeg-static.tar.xz.md5

echo ""
echo "✅ FFmpeg installed successfully!"
echo ""
echo "Location: $INSTALL_DIR/ffmpeg"
echo "Version:"
"$INSTALL_DIR/ffmpeg" -version | head -n1
echo ""
echo "To use this ffmpeg:"
echo "  1. Add to PATH: export PATH=\"$INSTALL_DIR:\$PATH\""
echo "  2. Or use absolute path: $INSTALL_DIR/ffmpeg"
echo ""
echo "For this project, pydub will automatically find it if bin/ is in your PATH."
