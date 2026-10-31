#!/bin/bash
# NotchFlow DMG Installer Creator
# Packages dist/NotchFlow.app into a distributable .dmg with Applications symlink

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

# Ensure NotchFlow.app is built
if [ ! -d "dist/NotchFlow.app" ]; then
    echo "==> NotchFlow.app not found in dist/. Packaging app first..."
    bash "$SCRIPT_DIR/package_app.sh"
fi

DIST_DIR="$ROOT_DIR/dist"
DMG_NAME="NotchFlow-Installer.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
VOL_NAME="NotchFlow Installer"
STAGING_DIR="/tmp/notchflow_dmg_staging"

echo "==> Preparing DMG staging area..."
rm -rf "$STAGING_DIR"
rm -f "$DMG_PATH"
mkdir -p "$STAGING_DIR"

# Copy .app bundle
echo "==> Copying NotchFlow.app..."
cp -R "dist/NotchFlow.app" "$STAGING_DIR/NotchFlow.app"

# Create symlink to /Applications
echo "==> Creating /Applications symlink..."
ln -s /Applications "$STAGING_DIR/Applications"

# Build DMG using hdiutil
echo "==> Creating compressed disk image: $DMG_PATH..."
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo "==> Success! DMG created at:"
echo "    $DMG_PATH"
echo "    Size: $(du -h "$DMG_PATH" | cut -f1)"
