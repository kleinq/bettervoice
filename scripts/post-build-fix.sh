#!/bin/bash
# Post-build script to fix whisper library loading
# This runs OUTSIDE Xcode sandbox so it can create symlinks

FRAMEWORKS_DIR="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"

echo "🔧 Post-build fix: Creating whisper symlink..."
echo "Frameworks dir: ${FRAMEWORKS_DIR}"

cd "${FRAMEWORKS_DIR}" 2>/dev/null || {
    echo "⚠️  Frameworks directory not found, skipping"
    exit 0
}

if [ -f "libwhisper.1.8.0.dylib" ]; then
    # Remove old symlink if exists
    rm -f libwhisper.1.dylib 2>/dev/null || true
    
    # Create new symlink
    ln -sf libwhisper.1.8.0.dylib libwhisper.1.dylib
    
    if [ -L "libwhisper.1.dylib" ]; then
        echo "✅ Successfully created symlink: libwhisper.1.dylib -> libwhisper.1.8.0.dylib"
        ls -la libwhisper*
    else
        echo "❌ Failed to create symlink"
        exit 1
    fi
else
    echo "⚠️  libwhisper.1.8.0.dylib not found in ${FRAMEWORKS_DIR}"
fi
