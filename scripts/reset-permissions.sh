#!/bin/bash
# Reset BetterVoice permissions for testing
# Run this when you need to test permission prompts again

set -e

BUNDLE_ID="com.bettervoice.BetterVoice"

echo "🔄 Resetting permissions for BetterVoice..."
echo ""

# Reset microphone permission
echo "📢 Resetting Microphone permission..."
tccutil reset Microphone "$BUNDLE_ID" 2>/dev/null && echo "  ✅ Microphone reset" || echo "  ℹ️  No microphone permission to reset"

# Reset accessibility permission  
echo "♿ Resetting Accessibility permission..."
tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null && echo "  ✅ Accessibility reset" || echo "  ℹ️  No accessibility permission to reset"

# Reset screen recording permission
echo "📺 Resetting Screen Recording permission..."
tccutil reset ScreenCapture "$BUNDLE_ID" 2>/dev/null && echo "  ✅ Screen Recording reset" || echo "  ℹ️  No screen recording permission to reset"

echo ""
echo "✅ Permission reset complete!"
echo ""
echo "💡 Next steps:"
echo "   1. Quit BetterVoice if running"
echo "   2. Rebuild and run from Xcode"
echo "   3. Permission dialogs will appear on first use"
