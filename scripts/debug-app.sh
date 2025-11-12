#!/bin/bash
# Debug script to check BetterVoice app status

echo "🔍 BetterVoice Debug Information"
echo "================================"
echo ""

# Check if app is running
echo "1. Process Status:"
if pgrep -x "BetterVoice" > /dev/null; then
    echo "   ✅ BetterVoice is RUNNING"
    ps aux | grep -i BetterVoice | grep -v grep | grep -v debug
else
    echo "   ❌ BetterVoice is NOT running"
fi
echo ""

# Check recent crash logs
echo "2. Recent Crash Logs:"
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
if ls -t "$CRASH_DIR"/BetterVoice* 2>/dev/null | head -1 > /dev/null; then
    echo "   ⚠️  Crash logs found:"
    ls -t "$CRASH_DIR"/BetterVoice* 2>/dev/null | head -3
    echo ""
    echo "   Latest crash excerpt:"
    LATEST=$(ls -t "$CRASH_DIR"/BetterVoice* 2>/dev/null | head -1)
    head -30 "$LATEST"
else
    echo "   ✅ No crash logs found"
fi
echo ""

# Check console logs
echo "3. Recent Console Logs (last 2 minutes):"
log show --predicate 'process == "BetterVoice"' --last 2m --info 2>/dev/null | tail -20 || echo "   No logs available via 'log' command"
echo ""

# Check app location and signature
echo "4. App Information:"
APP_PATH=$(mdfind "kMDItemCFBundleIdentifier == 'com.bettervoice.BetterVoice'" | head -1)
if [ -n "$APP_PATH" ]; then
    echo "   Location: $APP_PATH"
    echo "   Size: $(du -sh "$APP_PATH" | cut -f1)"
    echo "   Code Signature:"
    codesign -dvv "$APP_PATH" 2>&1 | grep -E "(Signature|Authority|TeamIdentifier)" | head -5
else
    echo "   ⚠️  App not found in Spotlight index"
    echo "   Checking common locations..."
    if [ -d "/Applications/BetterVoice.app" ]; then
        echo "   Found: /Applications/BetterVoice.app"
        APP_PATH="/Applications/BetterVoice.app"
    elif [ -d "$HOME/Applications/BetterVoice.app" ]; then
        echo "   Found: $HOME/Applications/BetterVoice.app"
        APP_PATH="$HOME/Applications/BetterVoice.app"
    fi
fi
echo ""

# Check permissions
echo "5. Required Permissions:"
echo "   Checking system database..."
# Microphone
MIC_STATUS=$(sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT service,allowed FROM access WHERE service='kTCCServiceMicrophone' AND client='com.bettervoice.BetterVoice';" 2>/dev/null || echo "Unable to check")
if [ -n "$MIC_STATUS" ]; then
    echo "   Microphone: $MIC_STATUS"
else
    echo "   Microphone: Not configured"
fi

# Accessibility
ACC_STATUS=$(sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT service,allowed FROM access WHERE service='kTCCServiceAccessibility' AND client='com.bettervoice.BetterVoice';" 2>/dev/null || echo "Unable to check")
if [ -n "$ACC_STATUS" ]; then
    echo "   Accessibility: $ACC_STATUS"
else
    echo "   Accessibility: Not configured"
fi
echo ""

# Check frameworks
if [ -n "$APP_PATH" ]; then
    echo "6. Frameworks Check:"
    FRAMEWORKS_DIR="$APP_PATH/Contents/Frameworks"
    if [ -d "$FRAMEWORKS_DIR" ]; then
        echo "   Frameworks directory exists"
        echo "   Whisper libraries:"
        ls -lh "$FRAMEWORKS_DIR"/libwhisper* 2>/dev/null || echo "   ⚠️  No whisper libraries found"
        if [ -L "$FRAMEWORKS_DIR/libwhisper.1.dylib" ]; then
            echo "   ✅ Symlink exists:"
            ls -la "$FRAMEWORKS_DIR/libwhisper.1.dylib"
        else
            echo "   ❌ Symlink missing: libwhisper.1.dylib"
        fi
    else
        echo "   ❌ Frameworks directory not found"
    fi
    echo ""
fi

# Check Info.plist
if [ -n "$APP_PATH" ]; then
    echo "7. App Configuration:"
    INFO_PLIST="$APP_PATH/Contents/Info.plist"
    if [ -f "$INFO_PLIST" ]; then
        echo "   Bundle ID: $(defaults read "$INFO_PLIST" CFBundleIdentifier 2>/dev/null)"
        echo "   Version: $(defaults read "$INFO_PLIST" CFBundleShortVersionString 2>/dev/null)"
        echo "   LSUIElement: $(defaults read "$INFO_PLIST" LSUIElement 2>/dev/null)"
    fi
fi
echo ""

echo "================================"
echo "Debug information collected!"
echo ""
echo "Next steps:"
echo "1. If app is crashing, check the crash log above"
echo "2. If app is running but no menu bar, try:"
echo "   killall BetterVoice && open -a BetterVoice"
echo "3. Check Console.app for real-time logs"
echo "4. Grant required permissions in System Settings"
