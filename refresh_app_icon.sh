#!/bin/bash

echo "🔄 Refreshing BetterVoice app icon..."

# Kill the BetterVoice app if running
killall BetterVoice 2>/dev/null

# Clean build
echo "📦 Cleaning build..."
cd /Users/robertwinder/Projects/bettervoice/BetterVoice
xcodebuild clean -scheme BetterVoice > /dev/null 2>&1

# Rebuild
echo "🔨 Rebuilding app..."
xcodebuild -scheme BetterVoice -configuration Debug build > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Build succeeded"
else
    echo "❌ Build failed"
    exit 1
fi

# Clear icon caches
echo "🗑️  Clearing icon cache..."
rm -rf ~/Library/Caches/com.apple.iconservices 2>/dev/null

# Re-register with LaunchServices
echo "📝 Re-registering with LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain user > /dev/null 2>&1
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R /Users/robertwinder/Library/Developer/Xcode/DerivedData/BetterVoice-*/Build/Products/Debug/BetterVoice.app 2>/dev/null

# Restart Dock and Finder to refresh icons
echo "🔄 Restarting Dock and Finder..."
killall Dock
killall Finder 2>/dev/null

echo ""
echo "✅ Icon refresh complete!"
echo ""
echo "📌 Next steps:"
echo "   1. Launch BetterVoice from Xcode or Finder"
echo "   2. Check System Settings > Privacy & Security > Accessibility"
echo "   3. The icon should now appear"
echo ""
echo "💡 If the icon still doesn't appear, you may need to:"
echo "   - Remove BetterVoice from Accessibility list"
echo "   - Launch the app again to re-add it"
echo ""
