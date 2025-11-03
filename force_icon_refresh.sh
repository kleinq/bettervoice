#!/bin/bash

echo "🔧 Force System Settings icon refresh..."

# 1. Quit BetterVoice
echo "1️⃣  Quitting BetterVoice..."
killall BetterVoice 2>/dev/null

# 2. Quit System Settings
echo "2️⃣  Quitting System Settings..."
killall "System Settings" 2>/dev/null

# 3. Clear ALL icon caches
echo "3️⃣  Clearing all icon caches..."
sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null
rm -rf ~/Library/Caches/com.apple.iconservices.store 2>/dev/null
rm -rf ~/Library/Caches/com.apple.iconservices 2>/dev/null

# 4. Clear TCC cache
echo "4️⃣  Clearing TCC cache..."
killall -HUP cfprefsd

# 5. Reset LaunchServices
echo "5️⃣  Resetting LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain user
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R ~/Library/Developer/Xcode/DerivedData/BetterVoice-*/Build/Products/Debug/BetterVoice.app 2>/dev/null

# 6. Touch the app to update modification time
echo "6️⃣  Updating app timestamp..."
touch ~/Library/Developer/Xcode/DerivedData/BetterVoice-*/Build/Products/Debug/BetterVoice.app

# 7. Restart Dock and Finder
echo "7️⃣  Restarting Dock and Finder..."
killall Dock
killall Finder

echo ""
echo "✅ Done!"
echo ""
echo "📌 Next steps:"
echo "   1. Wait 5 seconds for Dock/Finder to restart"
echo "   2. Launch BetterVoice from Finder or Applications"
echo "   3. Grant accessibility permission when prompted"
echo "   4. Check System Settings > Privacy & Security > Accessibility"
echo ""
echo "⚠️  If the icon STILL doesn't appear, you may need to:"
echo "   - Restart your Mac (nuclear option)"
echo "   - Or use CFBundleIconFile instead of asset catalog"
echo ""
