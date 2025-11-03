# Fix BetterVoice Icon in System Settings

## The icon appears in dialogs but not in System Settings? Here's the fix:

System Settings caches app icons separately from the main icon cache. Since the icon is already showing in app dialogs, we just need to force System Settings to refresh.

### Steps:

1. **Open System Settings**
   - Go to **Privacy & Security** > **Accessibility**

2. **Remove BetterVoice from the list**
   - Click the "BetterVoice" entry to select it
   - Click the **"-"** (minus) button at the bottom of the list
   - This removes BetterVoice from accessibility permissions

3. **Quit BetterVoice** if it's running
   - Right-click the menu bar icon and select "Quit"
   - Or run: `killall BetterVoice`

4. **Clear System Settings cache** (optional but recommended)
   ```bash
   killall -HUP cfprefsd
   killall System\ Settings
   ```

5. **Launch BetterVoice again**
   - Open from Applications folder or Finder
   - Or build and run from Xcode

6. **Re-grant Accessibility permission**
   - When prompted, click "Open System Settings"
   - In System Settings > Privacy & Security > Accessibility
   - **Enable the toggle** next to BetterVoice
   - The icon should now appear! 🎉

### Why this works:

- System Settings takes a snapshot of the app icon when you first grant permission
- That snapshot is cached even if you update the app
- Removing and re-adding the permission forces it to take a fresh snapshot
- Since the icon is already in the app bundle (as proven by it showing in dialogs), the new snapshot will include it

### Alternative (if above doesn't work):

If the icon still doesn't appear, try this nuclear option:

```bash
# Remove ALL icon caches and LaunchServices database
sudo rm -rf /Library/Caches/com.apple.iconservices.store
rm -rf ~/Library/Caches/com.apple.iconservices
killall Finder
killall Dock
```

Then repeat steps 1-6 above.
