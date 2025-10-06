#!/bin/bash
set -e

# This script runs OUTSIDE the sandbox as a post-build action
FRAMEWORKS_DIR="$1"

echo "Creating whisper symlink in: ${FRAMEWORKS_DIR}"

if [ ! -d "${FRAMEWORKS_DIR}" ]; then
    echo "ERROR: Frameworks directory does not exist: ${FRAMEWORKS_DIR}"
    exit 1
fi

cd "${FRAMEWORKS_DIR}"

if [ -f "libwhisper.1.8.0.dylib" ]; then
    ln -sf libwhisper.1.8.0.dylib libwhisper.1.dylib
    echo "✅ Created symlink: libwhisper.1.dylib -> libwhisper.1.8.0.dylib"
    ls -la libwhisper*
else
    echo "ERROR: libwhisper.1.8.0.dylib not found"
    exit 1
fi
