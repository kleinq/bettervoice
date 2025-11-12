# BetterVoice Distribution Guide

This guide covers how to package and distribute BetterVoice to other Mac users.

## Quick Start

To create a distributable DMG:

```bash
make release
```

This will:
1. Build the app in Release mode
2. Fix the whisper library symlink
3. Create a DMG file ready for distribution

## Packaging Options

### Option 1: Build and Package (Recommended)

Build and package in one command:

```bash
make release
```

This creates `BetterVoice-v1.0.dmg` in the project root.

### Option 2: Package Existing Build

If you've already built the app and just want to package it:

```bash
make package
```

### Option 3: Manual Packaging

For more control, use the packaging script directly:

```bash
./scripts/package-app.sh [OPTIONS]
```

Available options:
- `--skip-build` - Skip building, package existing build
- `--sign <DEVELOPER_ID>` - Code sign with Developer ID
- `--help` - Show help message

## Distribution Methods

### 1. Direct Distribution (Simplest)

Share the DMG file directly with users via:
- Email
- Cloud storage (Dropbox, Google Drive, etc.)
- File sharing services

**User Installation:**
1. Download and mount the DMG
2. Drag BetterVoice.app to Applications
3. Right-click the app and select "Open" (first time only)
4. Grant required permissions

**Important:** Without code signing, users will see a security warning on first launch.

### 2. GitHub Releases (Recommended for Open Source)

Upload the DMG as a release asset:

```bash
# Create a new release
gh release create v1.0 "BetterVoice-v1.0.dmg" \
  --title "BetterVoice v1.0" \
  --notes "Release notes here"

# Or upload to existing release
gh release upload v1.0 "BetterVoice-v1.0.dmg"
```

### 3. Web Hosting

Upload the DMG to a web server and provide a download link:

```html
<a href="https://yourserver.com/BetterVoice-v1.0.dmg">Download BetterVoice</a>
```

### 4. Homebrew Cask (Advanced)

For wider distribution via Homebrew:

1. Create a cask formula
2. Submit to homebrew-cask repository
3. Users install via: `brew install bettervoice`

## Code Signing & Notarization

For professional distribution without security warnings, you need:

### Requirements

- Apple Developer Account ($99/year)
- Developer ID Application certificate
- App-specific password for notarization

### Code Signing

Build and sign in one step:

```bash
./scripts/package-app.sh --sign "Developer ID Application: Your Name (TEAM_ID)"
```

Or sign manually:

```bash
# Sign all frameworks
codesign --force --sign "Developer ID Application: Your Name" \
  BetterVoice.app/Contents/Frameworks/*.dylib

# Sign the app bundle
codesign --force --deep --sign "Developer ID Application: Your Name" \
  --options runtime \
  --entitlements BetterVoice/BetterVoice/BetterVoice.entitlements \
  BetterVoice.app

# Verify
codesign --verify --verbose BetterVoice.app
```

### Notarization

After signing, submit for notarization:

```bash
# 1. Create a ZIP of the app
ditto -c -k --keepParent BetterVoice.app BetterVoice.zip

# 2. Submit for notarization
xcrun notarytool submit BetterVoice.zip \
  --apple-id "your@email.com" \
  --password "app-specific-password" \
  --team-id "TEAM_ID" \
  --wait

# 3. Staple the notarization ticket
xcrun stapler staple BetterVoice.app

# 4. Create DMG with notarized app
./scripts/package-app.sh --skip-build
```

### App-Specific Password

Create an app-specific password:
1. Go to https://appleid.apple.com
2. Sign in with your Apple ID
3. Generate an app-specific password
4. Save it securely

## What's Included in the DMG

The DMG contains:
- **BetterVoice.app** - The main application
- **Applications symlink** - For easy drag-and-drop installation
- **README.txt** - Installation instructions for users

## User Requirements

Your users need:
- macOS 12.4 or later
- Microphone access permission
- Accessibility access permission
- Input Monitoring permission

## First-Time Installation (Without Code Signing)

Users will need to bypass macOS Gatekeeper:

**Method 1: Right-click Open**
1. Right-click BetterVoice.app
2. Select "Open"
3. Click "Open" in the security dialog

**Method 2: Terminal**
```bash
xattr -cr /Applications/BetterVoice.app
```

**Method 3: System Settings**
1. Try to open the app (it will be blocked)
2. Go to System Settings > Privacy & Security
3. Click "Open Anyway"

## Troubleshooting

### Users Can't Open the App

**Problem:** "BetterVoice can't be opened because it is from an unidentified developer"

**Solution:**
- Use the right-click method above
- Or code sign and notarize the app

### Permissions Issues

**Problem:** App can't access microphone or paste text

**Solution:**
- Direct users to System Settings > Privacy & Security
- Enable required permissions for BetterVoice
- See PERMISSIONS_GUIDE.md for details

### Library Loading Errors

**Problem:** App crashes on launch with library errors

**Solution:**
- Ensure the packaging script completed successfully
- The whisper library symlink must be created correctly
- Check that all frameworks are bundled

### DMG Won't Mount

**Problem:** DMG is corrupted or won't mount

**Solution:**
- Re-run the packaging script
- Check disk space during packaging
- Verify DMG integrity: `hdiutil verify BetterVoice-v1.0.dmg`

## Testing Your Distribution Package

Before distributing, test the DMG:

1. **Mount the DMG:**
   ```bash
   open BetterVoice-v1.0.dmg
   ```

2. **Install to test location:**
   ```bash
   cp -R /Volumes/BetterVoice/BetterVoice.app ~/Desktop/
   ```

3. **Test the app:**
   ```bash
   open ~/Desktop/BetterVoice.app
   ```

4. **Verify permissions:**
   - Test microphone access
   - Test global hotkey
   - Test paste functionality

5. **Check code signature (if signed):**
   ```bash
   codesign --verify --verbose ~/Desktop/BetterVoice.app
   spctl --assess --verbose ~/Desktop/BetterVoice.app
   ```

## Versioning

Update version before releasing:

1. Edit `BetterVoice/BetterVoice/Info.plist`
2. Update `CFBundleShortVersionString` (e.g., "1.1")
3. Update `CFBundleVersion` (e.g., "1.1.0")
4. Rebuild and package

## Release Checklist

Before distributing:

- [ ] Update version number in Info.plist
- [ ] Test all core functionality
- [ ] Run on clean macOS installation
- [ ] Update CHANGELOG.md
- [ ] Create release notes
- [ ] Build with `make release`
- [ ] Test the DMG on another Mac
- [ ] (Optional) Code sign and notarize
- [ ] Upload to distribution platform
- [ ] Update documentation links
- [ ] Announce release

## Automation (CI/CD)

For automated releases, use GitHub Actions:

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive

      - name: Build and Package
        run: make release

      - name: Upload DMG
        uses: actions/upload-artifact@v3
        with:
          name: BetterVoice-DMG
          path: '*.dmg'

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: '*.dmg'
```

## Support

For distribution issues:
- Check existing issues on GitHub
- Review logs: `~/Library/Logs/BetterVoice/`
- Contact support with system info:
  ```bash
  sw_vers  # macOS version
  codesign -dvvv /path/to/BetterVoice.app  # Signature info
  ```

## Legal Considerations

Before distributing:
- Include appropriate licenses (see LICENSE file)
- Comply with whisper.cpp license (MIT)
- Include privacy policy if using cloud services
- Comply with Apple's distribution guidelines

## Next Steps

- Consider Mac App Store distribution
- Implement automatic updates (using Sparkle framework)
- Set up crash reporting (using Sentry or similar)
- Add analytics (with user consent)

---

For build issues, see [BUILDING.md](BUILDING.md)
For permissions setup, see [PERMISSIONS_GUIDE.md](../PERMISSIONS_GUIDE.md)
