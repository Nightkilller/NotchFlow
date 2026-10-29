#!/bin/bash
# NotchFlow App Bundle Packager
# Builds and packages a native macOS .app bundle with full TCC permissions and resources

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

echo "==> Building NotchFlow release binary..."
bash ./build.sh release

DIST_DIR="$ROOT_DIR/dist"
APP_NAME="NotchFlow.app"
APP_DIR="$DIST_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Creating application bundle layout at $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
echo "==> Installing executable..."
cp ".build/release/NotchFlow" "$MACOS_DIR/NotchFlow"
chmod +x "$MACOS_DIR/NotchFlow"

# Copy Info.plist
echo "==> Installing Info.plist with TCC entitlements..."
cp "Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"

# Create PkgInfo
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Copy App Icon if present
if [ -f "Packaging/AppIcon.icns" ]; then
    echo "==> Installing AppIcon.icns..."
    cp "Packaging/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Copy Whisper model into bundle Resources
if [ ! -f "Models/ggml-base.en.bin" ]; then
    bash ./scripts/download_model.sh
fi
if [ -f "Models/ggml-base.en.bin" ]; then
    echo "==> Installing Whisper model into Resources..."
    cp "Models/ggml-base.en.bin" "$RESOURCES_DIR/ggml-base.en.bin"
    mkdir -p "$HOME/Library/Application Support/NotchFlow/Models"
    cp "Models/ggml-base.en.bin" "$HOME/Library/Application Support/NotchFlow/Models/ggml-base.en.bin"
fi

# Ad-hoc codesign the bundle
echo "==> Applying ad-hoc codesignature..."
codesign --force --deep --sign - "$APP_DIR"

echo "==> Success! NotchFlow.app created cleanly at:"
echo "    $APP_DIR"
echo "    To launch: open \"$APP_DIR\""
