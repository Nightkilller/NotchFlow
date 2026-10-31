#!/bin/bash
# NotchFlow build script
# Works with Command Line Tools (no Xcode required)
# SwiftUI macros need explicit plugin loading since CLT doesn't bundle SwiftUIMacros

PLUGIN_FLAGS="-Xswiftc -load-plugin-library -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/libSwiftMacros.dylib"

case "${1:-build}" in
    build)
        echo "Building NotchFlow..."
        swift build $PLUGIN_FLAGS
        ;;
    run)
        echo "Building and running NotchFlow..."
        swift run $PLUGIN_FLAGS NotchFlow
        ;;
    release)
        echo "Building release..."
        swift build -c release $PLUGIN_FLAGS
        ;;
    package)
        echo "Packaging NotchFlow.app bundle..."
        bash ./scripts/package_app.sh
        ;;
    dmg)
        echo "Creating NotchFlow-Installer.dmg..."
        bash ./scripts/create_dmg.sh
        ;;
    clean)
        echo "Cleaning..."
        swift package clean
        ;;
    *)
        echo "Usage: ./build.sh [build|run|release|package|dmg|clean]"
        exit 1
        ;;
esac
