# Swift Package Manager Dependencies

## Adding GRDB.swift to Xcode Project

**Manual Steps Required** (Xcode GUI):

1. **Open Xcode Project**: `BetterVoice.xcodeproj`

2. **Add Package Dependency**:
   - Select project in navigator (blue icon at top)
   - Select `BetterVoice` project (not target)
   - Go to **Package Dependencies** tab
   - Click **+** button

3. **Enter Package URL**:
   ```
   https://github.com/groue/GRDB.swift.git
   ```

4. **Dependency Rule**:
   - Choose: **Up to Next Major Version**
   - Version: `6.24.0`
   - Click **Add Package**

5. **Add to Target**:
   - Select `GRDB` product
   - Check `BetterVoice` target
   - Click **Add Package**

6. **Verify**:
   - Package should appear under "Package Dependencies"
   - `import GRDB` should work in Swift files

## Alternative: Command Line (if preferred)

If you prefer command-line SPM integration:

```bash
cd /Users/robertwinder/Projects/hack/bettervoice/BetterVoice

# Note: This creates a standalone SPM package, not Xcode integration
# You'll still need to add via Xcode GUI for proper project integration
```

For Xcode projects, **GUI method is recommended** as it properly configures build settings and framework search paths.

---

**Status**: Ready for manual addition via Xcode
**Required for**: T033 (DatabaseManager), T048 (LearningService)
