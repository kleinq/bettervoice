# Fallback Icon Fix for System Settings

If the aggressive cache clearing still didn't work, we can add an explicit icon reference to Info.plist.

## Option: Add CFBundleIconFile to Info.plist

This is the older method (pre-asset catalog) that System Settings always respects:

1. Add this to `BetterVoice/BetterVoice/Info.plist` after line 14:

```xml
<key>CFBundleIconFile</key>
<string>AppIcon</string>
```

2. Rebuild the app
3. Run the force_icon_refresh.sh script again
4. Launch BetterVoice and re-grant accessibility permission

## Why this works:

- Asset catalogs (Assets.xcassets) are the modern way to handle icons
- But System Settings on some macOS versions caches asset catalog icons poorly
- CFBundleIconFile is the legacy method that System Settings always respects
- Both can coexist - the .icns file is already being generated from the asset catalog

## Alternative: Restart Mac

If even CFBundleIconFile doesn't work, a full restart of macOS will definitely clear all icon caches.

```bash
sudo reboot
```

After restart:
1. Launch BetterVoice
2. Grant accessibility permission
3. Icon should appear in System Settings
