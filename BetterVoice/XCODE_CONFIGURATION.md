# Xcode Project Configuration Instructions

## T002: GRDB.swift SPM Dependency ✅
Follow instructions in `SPM_DEPENDENCIES.md` to add GRDB via Xcode GUI.

## T003: whisper.cpp C++ Bridging ✅

Submodule added. Now configure in Xcode:

### 1. Add Bridging Header
- Project Navigator → BetterVoice target → Build Settings
- Search: "Objective-C Bridging Header"
- Set value: `BetterVoice/BetterVoice-Bridging-Header.h`

### 2. Add whisper.cpp Source Files
- Add these files to "Compile Sources" build phase:
  - `whisper.cpp/whisper.cpp`
  - `whisper.cpp/ggml.c`
  - `whisper.cpp/ggml-alloc.c`
  - `whisper.cpp/ggml-backend.c`
  - `whisper.cpp/ggml-quants.c`

- **How to add**:
  1. Select BetterVoice target → Build Phases
  2. Expand "Compile Sources"
  3. Click **+** button
  4. Navigate to `whisper.cpp/` directory
  5. Select the .cpp and .c files listed above
  6. Click **Add**

### 3. Configure C++ Compilation
- Build Settings → All → Combined
- **C++ Language Dialect**: `GNU++17` or `C++17`
- **C Language Dialect**: `GNU11` or `C11`
- **Enable Modules**: `YES`

### 4. Add Framework Search Paths
- Build Settings → Search Paths
- **Header Search Paths**: Add `$(PROJECT_DIR)/whisper.cpp`

### 5. Link Accelerate Framework
- BetterVoice target → General → Frameworks and Libraries
- Click **+** → Search "Accelerate.framework" → Add

## T004: Info.plist Configuration

Add these entries to `BetterVoice/Info.plist`:

```xml
<!-- Menu Bar App (no dock icon) -->
<key>LSUIElement</key>
<true/>

<!-- Permission Usage Descriptions (Required for permissions) -->
<key>NSMicrophoneUsageDescription</key>
<string>BetterVoice needs microphone access to record your voice for transcription.</string>

<key>NSAccessibilityUsageDescription</key>
<string>BetterVoice needs accessibility access to detect the active application and simulate text pasting.</string>

<key>NSScreenCaptureUsageDescription</key>
<string>BetterVoice needs screen recording permission to detect the active application window for context-aware text formatting.</string>
```

**How to add** (Xcode):
1. Select `Info.plist` in Project Navigator
2. Right-click → Open As → Source Code
3. Add the XML entries above inside the `<dict>` section
4. Save

**Alternative** (GUI):
1. Select `Info.plist`
2. Click **+** on any row
3. Type the key name (e.g., "Privacy - Microphone Usage Description")
4. Set value in the right column

## T004: Entitlements Configuration

Edit `BetterVoice/BetterVoice.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Sandbox (Required for distribution) -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- Microphone Access -->
    <key>com.apple.security.device.audio-input</key>
    <true/>

    <!-- Network Access (for cloud API enhancement) -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- User Selected Files (for model downloads) -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- Application Support folder access -->
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
</dict>
</plist>
```

## T004: Build Settings

### Deployment
- **Minimum Deployments**: macOS 12.0
- **Supported Platforms**: macOS

### Swift Compiler
- **Swift Language Version**: Swift 5
- **Optimization Level** (Debug): `-Onone`
- **Optimization Level** (Release): `-O` (Fast)

### Signing & Capabilities
- **Signing**: Automatic
- **Team**: (Your Apple Developer Team)
- **Bundle Identifier**: `com.bettervoice.BetterVoice`

### Capabilities (Add via Signing & Capabilities tab)
- ✅ **App Sandbox**
- ✅ **Hardened Runtime**
- ✅ **Audio Input**
- ✅ **Network (Outgoing Connections)**

## T005: SwiftLint Integration ✅

`.swiftlint.yml` created. To enable in Xcode:

### 1. Install SwiftLint
```bash
brew install swiftlint
```

### 2. Add Run Script Phase
- BetterVoice target → Build Phases
- Click **+** → New Run Script Phase
- Name: "SwiftLint"
- Shell: `/bin/sh`
- Script:
```bash
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```
- Move this phase above "Compile Sources"

---

## Verification Checklist

After configuration:

- [ ] Project builds successfully (`Cmd+B`)
- [ ] GRDB imported without errors: `import GRDB`
- [ ] whisper.cpp headers accessible
- [ ] Info.plist contains all 3 permission descriptions
- [ ] Entitlements file configured
- [ ] SwiftLint runs on build (warnings shown in navigator)
- [ ] No build errors related to C++ bridging

---

**Next Steps**: Once configured, proceed to Phase 3.2 (TDD - Write Tests First)
