#!/bin/bash
# BetterVoice Packaging Script
# Creates a distributable DMG for macOS

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     BetterVoice macOS App Packaging Script         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Configuration
APP_NAME="BetterVoice"
BUNDLE_ID="com.bettervoice.BetterVoice"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODE_PROJECT="${PROJECT_DIR}/BetterVoice/BetterVoice.xcodeproj"
BUILD_CONFIG="${BUILD_CONFIG:-Release}"
DERIVED_DATA="${PROJECT_DIR}/build"
DIST_DIR="${PROJECT_DIR}/dist"
DMG_NAME="${APP_NAME}"
VERSION=$(defaults read "${PROJECT_DIR}/BetterVoice/BetterVoice/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")

# Parse command line arguments
SKIP_BUILD=false
SIGN_APP=false
DEVELOPER_ID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --sign)
            SIGN_APP=true
            DEVELOPER_ID="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-build           Skip the build step (use existing build)"
            echo "  --sign <DEVELOPER_ID>  Code sign the app with Developer ID"
            echo "  --help                 Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Build and package"
            echo "  $0 --skip-build                       # Package existing build"
            echo "  $0 --sign 'Developer ID Application'  # Build, sign, and package"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}📋 Configuration:${NC}"
echo "  • Project: ${APP_NAME}"
echo "  • Version: ${VERSION}"
echo "  • Build Config: ${BUILD_CONFIG}"
echo "  • Code Signing: $([ "$SIGN_APP" = true ] && echo "Enabled ($DEVELOPER_ID)" || echo "Disabled (ad-hoc)")"
echo ""

# Step 1: Build the app (unless skipped)
if [ "$SKIP_BUILD" = false ]; then
    echo -e "${BLUE}🔨 Step 1: Building ${APP_NAME}...${NC}"
    cd "${PROJECT_DIR}/BetterVoice"

    xcodebuild clean \
        -project BetterVoice.xcodeproj \
        -scheme BetterVoice \
        -configuration "${BUILD_CONFIG}" \
        -derivedDataPath "${DERIVED_DATA}" \
        > /dev/null 2>&1

    if [ "$SIGN_APP" = true ]; then
        # Build with code signing
        xcodebuild build \
            -project BetterVoice.xcodeproj \
            -scheme BetterVoice \
            -configuration "${BUILD_CONFIG}" \
            -derivedDataPath "${DERIVED_DATA}" \
            CODE_SIGN_IDENTITY="$DEVELOPER_ID"
    else
        # Build with ad-hoc signing (no team required)
        xcodebuild build \
            -project BetterVoice.xcodeproj \
            -scheme BetterVoice \
            -configuration "${BUILD_CONFIG}" \
            -derivedDataPath "${DERIVED_DATA}" \
            CODE_SIGN_IDENTITY="-" \
            DEVELOPMENT_TEAM=""
    fi

    echo -e "${GREEN}✅ Build complete${NC}"
else
    echo -e "${YELLOW}⏭️  Step 1: Skipping build (using existing build)${NC}"
fi

# Locate the built app
APP_PATH=$(find "${DERIVED_DATA}/Build/Products" -name "${APP_NAME}.app" -type d | grep "${BUILD_CONFIG}" | head -n 1)

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ Error: Built app not found at expected location${NC}"
    echo "   Expected: ${DERIVED_DATA}/Build/Products/${BUILD_CONFIG}/${APP_NAME}.app"
    exit 1
fi

echo -e "${GREEN}✅ Found app at: ${APP_PATH}${NC}"
echo ""

# Step 2: Fix whisper library symlink
echo -e "${BLUE}🔧 Step 2: Fixing whisper library symlink...${NC}"
FRAMEWORKS_DIR="${APP_PATH}/Contents/Frameworks"

if [ -d "$FRAMEWORKS_DIR" ]; then
    cd "$FRAMEWORKS_DIR"

    if [ -f "libwhisper.1.8.0.dylib" ]; then
        rm -f libwhisper.1.dylib 2>/dev/null || true
        ln -sf libwhisper.1.8.0.dylib libwhisper.1.dylib

        if [ -L "libwhisper.1.dylib" ]; then
            echo -e "${GREEN}✅ Created symlink: libwhisper.1.dylib -> libwhisper.1.8.0.dylib${NC}"
        else
            echo -e "${RED}❌ Failed to create symlink${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠️  Warning: libwhisper.1.8.0.dylib not found${NC}"
        echo "   The app may not work without the whisper library"
    fi
else
    echo -e "${YELLOW}⚠️  Warning: Frameworks directory not found${NC}"
fi
echo ""

# Step 3: Code signing
echo -e "${BLUE}🔐 Step 3: Code signing the app...${NC}"

if [ "$SIGN_APP" = true ]; then
    # Sign with Developer ID
    echo "   Using Developer ID: $DEVELOPER_ID"

    # Sign all frameworks first
    if [ -d "$FRAMEWORKS_DIR" ]; then
        for framework in "$FRAMEWORKS_DIR"/*.{dylib,framework}; do
            if [ -e "$framework" ]; then
                codesign --force --sign "$DEVELOPER_ID" --timestamp "$framework" || true
            fi
        done
    fi

    # Sign the app bundle
    codesign --force --deep --sign "$DEVELOPER_ID" --timestamp \
        --options runtime \
        --entitlements "${PROJECT_DIR}/BetterVoice/BetterVoice/BetterVoice.entitlements" \
        "$APP_PATH"

    # Verify signature
    codesign --verify --verbose "$APP_PATH"
    echo -e "${GREEN}✅ Code signing complete${NC}"
else
    # Use ad-hoc signing
    echo "   Using ad-hoc signing (no Developer ID)"

    # CRITICAL: Re-sign all frameworks with ad-hoc signature to match the main app
    # This fixes "different Team IDs" error when copying to /Applications
    if [ -d "$FRAMEWORKS_DIR" ]; then
        echo "   Re-signing frameworks with ad-hoc signature..."
        for framework in "$FRAMEWORKS_DIR"/*.dylib "$FRAMEWORKS_DIR"/*.framework; do
            if [ -e "$framework" ]; then
                # Remove any existing signature and apply ad-hoc signature
                codesign --force --sign "-" "$framework" 2>/dev/null || true
                echo "   ✓ Signed: $(basename "$framework")"
            fi
        done
    fi

    # Sign the app bundle with ad-hoc signature
    codesign --force --deep --sign "-" "$APP_PATH" 2>/dev/null || true

    echo -e "${GREEN}✅ Ad-hoc code signing complete${NC}"
fi
echo ""

# Step 4: Create distribution directory structure
echo -e "${BLUE}📦 Step 4: Preparing distribution package...${NC}"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Copy app to dist directory
cp -R "$APP_PATH" "$DIST_DIR/"
echo -e "${GREEN}✅ Copied app to distribution directory${NC}"
echo ""

# Step 5: Create DMG
echo -e "${BLUE}💿 Step 5: Creating DMG...${NC}"

DMG_TEMP="${PROJECT_DIR}/tmp_dmg"
DMG_PATH="${PROJECT_DIR}/${DMG_NAME}-v${VERSION}.dmg"
VOLUME_NAME="${APP_NAME}"

# Remove old DMG if exists
rm -f "$DMG_PATH"
rm -rf "$DMG_TEMP"

# Create temporary DMG directory
mkdir -p "$DMG_TEMP"
cp -R "$APP_PATH" "$DMG_TEMP/"

# Create a link to Applications folder
ln -s /Applications "$DMG_TEMP/Applications"

# Create a README file for users
cat > "$DMG_TEMP/README.txt" << EOF
BetterVoice - Voice Dictation for macOS
Version ${VERSION}

INSTALLATION INSTRUCTIONS:
1. Drag ${APP_NAME}.app to the Applications folder
2. Open ${APP_NAME} from your Applications folder
3. Grant required permissions when prompted:
   - Microphone access (required for voice recording)
   - Accessibility access (required for global hotkeys)
   - Input Monitoring (required for paste functionality)

FIRST RUN:
- On first launch, macOS may show a security warning
- Go to System Settings > Privacy & Security
- Click "Open Anyway" to allow the app to run

USAGE:
- Press the global hotkey (default: Option+Space) to start recording
- Speak your text
- Release the hotkey to stop recording
- Your transcribed text will be pasted automatically

For more information, visit: https://github.com/bettervoice/bettervoice

TROUBLESHOOTING:
If the app doesn't open:
1. Right-click the app and select "Open"
2. Check System Settings > Privacy & Security for any blocks
3. Run: xattr -cr /Applications/${APP_NAME}.app

For permission issues, see PERMISSIONS_GUIDE.md in the repository.
EOF

# Calculate size for DMG
APP_SIZE=$(du -sm "$DMG_TEMP" | awk '{print $1}')
DMG_SIZE=$((APP_SIZE + 50))  # Add 50MB buffer

echo "  • Volume Name: ${VOLUME_NAME}"
echo "  • DMG Size: ${DMG_SIZE}MB"

# Create DMG
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    -fs HFS+ \
    -size ${DMG_SIZE}m \
    "$DMG_PATH"

# Clean up temp directory
rm -rf "$DMG_TEMP"

if [ -f "$DMG_PATH" ]; then
    DMG_FILE_SIZE=$(du -h "$DMG_PATH" | awk '{print $1}')
    echo -e "${GREEN}✅ DMG created successfully: ${DMG_NAME}-v${VERSION}.dmg (${DMG_FILE_SIZE})${NC}"
else
    echo -e "${RED}❌ Failed to create DMG${NC}"
    exit 1
fi
echo ""

# Step 6: Summary
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ✨ Packaging Complete! ✨              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📦 Distribution Package:${NC}"
echo "  • DMG: ${DMG_PATH}"
echo "  • App: ${DIST_DIR}/${APP_NAME}.app"
echo ""
echo -e "${BLUE}📤 Distribution Options:${NC}"
echo "  1. ${GREEN}Direct Distribution:${NC}"
echo "     Share the DMG file directly with users"
echo "     Users can mount and install the app"
echo ""
echo "  2. ${GREEN}GitHub Release:${NC}"
echo "     Upload the DMG as a release asset:"
echo "     gh release create v${VERSION} \"${DMG_PATH}\""
echo ""
echo "  3. ${GREEN}Web Hosting:${NC}"
echo "     Upload to a web server and share the download link"
echo ""

if [ "$SIGN_APP" = false ]; then
    echo -e "${YELLOW}⚠️  IMPORTANT: App uses ad-hoc code signing${NC}"
    echo "   The app is signed but not with an Apple Developer ID."
    echo ""
    echo "   Users will need to (first launch only):"
    echo "   1. Right-click the app and select 'Open'"
    echo "   2. Click 'Open' in the security dialog"
    echo "   Alternative: xattr -cr /Applications/${APP_NAME}.app"
    echo ""
    echo "   For wider distribution without warnings, consider:"
    echo "   • Code signing with Apple Developer ID certificate"
    echo "   • Notarizing with Apple (requires Developer account)"
    echo ""
    echo "   Run with --sign option for Developer ID signing:"
    echo "   $0 --sign 'Developer ID Application: Your Name (TEAM_ID)'"
    echo ""
fi

echo -e "${BLUE}🎉 Ready to distribute!${NC}"
echo ""
