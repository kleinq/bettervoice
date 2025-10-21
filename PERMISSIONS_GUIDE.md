# BetterVoice Permissions Guide

## Overview

BetterVoice requires certain macOS permissions to function properly. The app now automatically checks permissions on startup and provides multiple ways to grant them.

## Required Permissions

### 1. Microphone Access (Required)
**Why:** To capture your voice for transcription
**Impact if denied:** App cannot record audio at all

### 2. Accessibility Access (Required)
**Why:**
- To paste transcribed text into applications
- To detect the active application and context
- To provide better document type detection

**Impact if denied:** Text cannot be automatically pasted, limited app detection

### 3. Screen Recording (Optional)
**Why:** To detect browser URLs for better context detection
**Impact if denied:** URL-based context detection won't work (e.g., Gmail in browser)

**Note:** No actual screen recording occurs - this permission is only used to read window information.

## How Permission Checking Works

### On First Launch
1. Welcome screen appears
2. Permissions are requested step-by-step
3. App guides you through granting each permission
4. Cannot proceed until microphone permission is granted

### On Subsequent Launches
1. App checks all permissions at startup
2. If any required permissions are missing:
   - Alert dialog appears
   - Option to open Settings to grant permissions
   - Can dismiss and grant later

## Where to Check/Grant Permissions

### 1. Permissions Tab in Settings
- **Access:** Click BetterVoice menu bar icon → Settings → Permissions tab
- **Features:**
  - Live status display for all permissions
  - Color-coded indicators (green = granted, red = denied, orange = not determined)
  - One-click buttons to request/grant permissions
  - Auto-refresh every 2 seconds to detect permission changes
  - Manual refresh button
  - Overall status indicator

### 2. Menu Bar Indicator
- **Access:** Click BetterVoice menu bar icon
- **Features:**
  - Shows warning if permissions are missing
  - Example: "⚠️ Microphone permission needed"
  - Example: "⚠️ 2 permissions needed"
  - Visible immediately when opening menu

### 3. Startup Alert (After Onboarding)
- **Trigger:** Launched after first time, permissions missing
- **Features:**
  - Lists all missing permissions
  - Explains why each is needed
  - Button to open Settings
  - Option to dismiss ("Later")

## How to Grant Permissions

### Microphone
1. Click "Request" button in Permissions tab
2. macOS system prompt appears
3. Click "OK" to grant access
4. Status updates immediately

### Accessibility
1. Click "Open Settings" button in Permissions tab
2. macOS System Preferences opens to Security & Privacy → Accessibility
3. Click the lock icon to make changes
4. Check the box next to "BetterVoice"
5. Close System Preferences
6. Status updates automatically within 2 seconds

### Screen Recording
1. Click "Open Settings" button in Permissions tab
2. macOS System Preferences opens to Security & Privacy → Screen Recording
3. Click the lock icon to make changes
4. Check the box next to "BetterVoice"
5. Close System Preferences
6. Status updates automatically within 2 seconds

## Permission States

### Granted ✅
- Green checkmark icon
- "Granted" text
- Feature fully functional

### Denied ❌
- Red X icon
- "Open Settings" button (for Accessibility/Screen Recording)
- "Request" button (for Microphone)
- Feature non-functional

### Not Determined ⚠️
- Orange question mark icon
- Permission has not been requested yet
- "Request" button available

## Troubleshooting

### "App doesn't record anything"
**Solution:** Check microphone permission
1. Open Settings → Permissions
2. Ensure Microphone shows "Granted"
3. If not, click "Request" and approve

### "Text doesn't paste automatically"
**Solution:** Check accessibility permission
1. Open Settings → Permissions
2. Ensure Accessibility shows "Granted"
3. If not, click "Open Settings" and enable in System Preferences

### "Permission shows as granted but still not working"
**Solution:** Restart the app
1. Quit BetterVoice completely
2. Launch again
3. macOS sometimes requires a restart after granting permissions

### "I granted permission but status still shows denied"
**Solution:** Wait for auto-refresh or click Refresh button
- Auto-refresh happens every 2 seconds
- Or click the "Refresh" button in Permissions tab
- Or restart the app

## Implementation Details

### Files Modified

1. **BetterVoiceApp.swift** (Lines 147-261)
   - Added startup permission check
   - Shows alert if permissions missing (post-onboarding)
   - Helper functions for permission management

2. **SettingsView.swift** (Line 22-25)
   - Added PermissionsTab to settings
   - New tab with "lock.shield" icon

3. **PermissionsTab.swift** (Enhanced)
   - Added overall status indicator
   - Added manual refresh button
   - Added periodic auto-refresh (every 2 seconds)
   - Better UX with color-coded indicators

4. **MenuBarView.swift** (Lines 32, 51-83, 242-266)
   - Added permission warning display
   - Shows count of missing permissions
   - Checks permissions on appear

### Permission Flow

```
App Launch
    ↓
Check onboarding status
    ↓
[If onboarding complete]
    ↓
Check all permissions
    ↓
[If permissions missing]
    ↓
Show alert with options
    ↓
User can open Settings or dismiss
```

### Periodic Refresh

The PermissionsTab uses a Timer to check permissions every 2 seconds:
- Automatically detects when user grants permissions in System Settings
- No need to manually refresh or restart app
- Provides real-time feedback

## Best Practices

1. **Grant all required permissions** for best experience
2. **Check Permissions tab** if something isn't working
3. **Restart app** after granting permissions if issues persist
4. **Use the alert on startup** to quickly access Settings

## System Requirements

- macOS 12.0 or later (for BetterVoice)
- macOS 13.0 recommended (for best SwiftUI support)

## Privacy Notice

BetterVoice:
- ✅ Records audio ONLY when you press the hotkey
- ✅ Processes all transcription locally (whisper.cpp)
- ✅ Never uploads audio to servers
- ✅ Uses Screen Recording permission only to read window titles/URLs
- ✅ Never actually records your screen
- ✅ Stores transcription history locally only

Your privacy is protected - all processing happens on your device.
