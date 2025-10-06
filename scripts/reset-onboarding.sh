#!/bin/bash
# Reset onboarding flag to test welcome dialog

echo "🔄 Resetting BetterVoice onboarding..."

# Remove UserDefaults entry
defaults delete com.bettervoice.BetterVoice 2>/dev/null || true

echo "✅ Onboarding reset complete!"
echo ""
echo "💡 Next time you launch BetterVoice, the welcome dialog will appear."
