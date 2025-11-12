# Quick Distribution Guide

## For Distributors (You)

### Package the App for Distribution

**One command to build and package:**

```bash
make release
```

This will:
1. Build the app in Release mode
2. Fix the whisper library symlink automatically
3. Create `BetterVoice-v1.0.dmg` ready to distribute

**Alternative commands:**

```bash
make package          # Package existing build without rebuilding
make release          # Build Release version and create DMG
./scripts/package-app.sh --help  # See all options
```

### Distribute the DMG

Share `BetterVoice-v1.0.dmg` via:
- Email
- Cloud storage (Dropbox, Google Drive)
- GitHub Releases
- Your website

---

## For Recipients (Your Users)

### How to Install BetterVoice

1. **Download** the DMG file
2. **Double-click** to mount it
3. **Drag** BetterVoice.app to the Applications folder
4. **Right-click** BetterVoice in Applications and select "Open"
5. Click **"Open"** in the security dialog
6. **Grant permissions** when prompted:
   - Microphone access
   - Accessibility access
   - Input Monitoring

### First Launch Security Warning

macOS will show a security warning because the app is not from the App Store.

**To bypass this:**

**Option 1** (Easiest):
1. Right-click BetterVoice.app
2. Select "Open"
3. Click "Open" in the dialog

**Option 2** (If that doesn't work):
1. Try to open the app normally
2. Go to **System Settings > Privacy & Security**
3. Look for a message about BetterVoice being blocked
4. Click **"Open Anyway"**

**Option 3** (Terminal):
```bash
xattr -cr /Applications/BetterVoice.app
```

### Required Permissions

Grant these permissions in **System Settings > Privacy & Security**:

- **Microphone** - Required for voice recording
- **Accessibility** - Required for global hotkeys
- **Input Monitoring** - Required for paste functionality

### How to Use

1. Press **Option+Space** (default hotkey) to start recording
2. **Speak** your text
3. **Release** the hotkey to stop
4. Text will be **pasted automatically**

---

## Troubleshooting

### "BetterVoice can't be opened"
Use the right-click "Open" method above.

### App won't record audio
Grant Microphone permission in System Settings > Privacy & Security > Microphone

### Hotkey doesn't work
Grant Accessibility permission in System Settings > Privacy & Security > Accessibility

### Text won't paste
Grant Input Monitoring permission in System Settings > Privacy & Security > Input Monitoring

### Need to reset permissions?
```bash
./scripts/reset-permissions.sh
```

---

## System Requirements

- macOS 12.4 or later
- Microphone
- ~50MB disk space

---

## For Detailed Instructions

- **Distributors**: See [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md)
- **Developers**: See [docs/BUILDING.md](docs/BUILDING.md)
- **Users**: See [PERMISSIONS_GUIDE.md](PERMISSIONS_GUIDE.md)

---

## Support

Issues? Check:
- GitHub Issues: https://github.com/bettervoice/bettervoice/issues
- Logs: `~/Library/Logs/BetterVoice/`
- Documentation: [README.md](README.md)
