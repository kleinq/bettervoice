# BetterVoice Learning Assistant - Chrome Extension

Enables BetterVoice to learn from your edits in web applications like Gmail, Google Docs, and other browser-based editors.

## Installation

### Step 1: Install the Extension

1. Open Chrome and go to `chrome://extensions/`
2. Enable "Developer mode" (toggle in top right)
3. Click "Load unpacked"
4. Select the `BetterVoiceExtension` folder

### Step 2: Note the Extension ID

After loading, you'll see an Extension ID like: `abcdefghijklmnopqrstuvwxyz123456`

Copy this ID - you'll need it for the next step.

### Step 3: Configure Native Messaging

1. Edit `com.bettervoice.learning.json`
2. Replace `EXTENSION_ID_WILL_BE_ADDED_HERE` with your actual extension ID
3. Install the native messaging manifest:

```bash
# For Chrome
mkdir -p ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/
cp com.bettervoice.learning.json ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/

# For Chrome Beta
mkdir -p ~/Library/Application\ Support/Google/Chrome\ Beta/NativeMessagingHosts/
cp com.bettervoice.learning.json ~/Library/Application\ Support/Google/Chrome\ Beta/NativeMessagingHosts/

# For Chromium
mkdir -p ~/Library/Application\ Support/Chromium/NativeMessagingHosts/
cp com.bettervoice.learning.json ~/Library/Application\ Support/Chromium/NativeMessagingHosts/
```

### Step 4: Verify Connection

1. Open Chrome DevTools console (F12)
2. Paste text from BetterVoice into Gmail or Google Docs
3. Look for logs: `[BetterVoice] Monitoring started`
4. Make an edit and check for: `[BetterVoice] Edit detected!`

## How It Works

1. **BetterVoice pastes transcription** → App detects Chrome is focused
2. **Extension activates** → Monitors the contenteditable element
3. **You make edits** → Extension detects changes (2s debounce)
4. **Learning happens** → Changes sent to BetterVoice via native messaging
5. **Future transcriptions improve** → Your corrections are applied automatically

## Supported Sites

- Gmail (compose, reply)
- Google Docs
- Notion
- Slack (web)
- Any contenteditable or textarea element

## Troubleshooting

### Extension not detecting edits

1. Check DevTools console for errors
2. Verify native messaging host is installed correctly
3. Make sure BetterVoice app is running
4. Try reloading the extension

### Native messaging connection fails

1. Verify extension ID in `com.bettervoice.learning.json`
2. Check path to BetterVoice.app is correct
3. Restart Chrome completely

### Logs to check

**Browser console:**
```
[BetterVoice] Content script loaded
[BetterVoice Background] Connected to native host
[BetterVoice] Monitoring started on DIV
[BetterVoice] Edit detected!
```

**BetterVoice logs:**
```
🔌 Native messaging host started
📥 Received message from extension: EDIT_DETECTED
✅ Edit detected from web app
```

## Privacy

- Extension only monitors when BetterVoice pastes text
- No data sent to external servers
- All communication stays local (Chrome ↔ BetterVoice app)
- Extension cannot access other tabs or browsing history
