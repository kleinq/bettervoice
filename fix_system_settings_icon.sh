#!/bin/bash

echo "🔧 BetterVoice System Settings Icon Fix"
echo "========================================"
echo ""

# Step 1: Kill BetterVoice if running
echo "Step 1: Stopping BetterVoice..."
killall BetterVoice 2>/dev/null
sleep 1

# Step 2: Clear all icon and permission caches
echo "Step 2: Clearing icon and permission caches..."

# Clear icon services cache
sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null
rm -rf ~/Library/Caches/com.apple.iconservices 2>/dev/null

# Clear Launch Services database
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

# Clear cfprefsd cache
killall -HUP cfprefsd 2>/dev/null

echo "✅ Caches cleared"
sleep 2

# Step 3: Reset Dock and Finder
echo "Step 3: Resetting Dock and Finder..."
killall Dock 2>/dev/null
killall Finder 2>/dev/null
echo "✅ Dock and Finder reset"
sleep 2

# Step 4: Remove app from TCC database (requires user interaction)
echo ""
echo "Step 4: Manual step required!"
echo "=============================="
echo ""
echo "Please do the following:"
echo "  1. Open System Settings"
echo "  2. Go to Privacy & Security > Accessibility"
echo "  3. Find 'BetterVoice' in the list"
echo "  4. Click the '-' (minus) button to remove it"
echo "  5. Close System Settings"
echo ""
read -p "Press ENTER when you've removed BetterVoice from Accessibility..."

echo ""
echo "Step 5: Killing System Settings to clear its cache..."
killall "System Settings" 2>/dev/null
killall SystemUIServer 2>/dev/null
sleep 2

# Step 6: Launch BetterVoice
echo ""
echo "Step 6: Launching BetterVoice..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "BetterVoice.app" -path "*/Build/Products/Debug/*" 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Could not find BetterVoice.app in DerivedData"
    echo "Please build the app first with Xcode, then run this script again."
    exit 1
fi

echo "Found app at: $APP_PATH"
open "$APP_PATH"

echo ""
echo "Step 7: Re-grant Accessibility permission"
echo "=========================================="
echo ""
echo "BetterVoice is now launching. When prompted:"
echo "  1. Click 'Open System Settings'"
echo "  2. Enable the toggle next to BetterVoice"
echo "  3. The icon should now appear! 🎉"
echo ""
echo "If BetterVoice doesn't prompt you automatically:"
echo "  1. Open System Settings manually"
echo "  2. Go to Privacy & Security > Accessibility"
echo "  3. Click the '+' button"
echo "  4. Navigate to: $APP_PATH"
echo "  5. Add it and enable the toggle"
echo ""
