#!/bin/bash
# View the latest BetterVoice crash log

CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
LATEST=$(ls -t "$CRASH_DIR"/BetterVoice*.ips 2>/dev/null | head -1)

if [ -z "$LATEST" ]; then
    echo "No crash logs found"
    exit 1
fi

echo "Latest crash log: $LATEST"
echo "========================================"
echo ""

# Extract the termination reason and exception
cat "$LATEST" | grep -A 20 "terminationReason\|exception\|termination\|Exception\|Termination" | head -50
echo ""
echo "========================================"
echo ""
echo "Full crash trace:"
cat "$LATEST" | grep -A 50 "lastExceptionBacktrace\|Crashed Thread" | head -100
