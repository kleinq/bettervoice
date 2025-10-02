# Building BetterVoice

## Quick Start

The easiest way to build and run BetterVoice is using the provided Makefile:

```bash
# Build and run the app
make run

# Just build
make build

# Clean build artifacts
make clean
```

## Why Use the Makefile?

The Makefile automatically handles a critical post-build step: **creating the whisper library symlink**.

### The Problem

The app depends on `libwhisper.1.dylib`, but the actual library file is `libwhisper.1.8.0.dylib`.

Xcode's build sandbox **blocks** creating symlinks during build phases, causing this error:
```
dyld[...]: Library not loaded: @rpath/libwhisper.1.dylib
  Referenced from: .../BetterVoice.app/Contents/MacOS/BetterVoice.debug.dylib
  Reason: tried: '.../libwhisper.1.dylib' (no such file)
```

### The Solution

The Makefile runs a post-build script **outside** the Xcode sandbox to create the required symlink:

```bash
cd BetterVoice.app/Contents/Frameworks
ln -sf libwhisper.1.8.0.dylib libwhisper.1.dylib
```

## Building from Xcode

If you build directly from Xcode (⌘B), you **must** manually run the post-build script:

```bash
./scripts/post-build-fix.sh
```

Or simply use `make build` after Xcode builds to apply the fix.

## Alternative: Direct xcodebuild

```bash
# Build
xcodebuild -project BetterVoice/BetterVoice.xcodeproj \
           -scheme BetterVoice \
           -configuration Debug

# Apply fix
./scripts/post-build-fix.sh

# Run
open /Users/robertwinder/Library/Developer/Xcode/DerivedData/BetterVoice-*/Build/Products/Debug/BetterVoice.app
```

## Troubleshooting

### Error: "Library not loaded: @rpath/libwhisper.1.dylib"

**Solution:** Run the post-build fix:
```bash
make build  # This automatically applies the fix
```

### Check if symlink exists

```bash
ls -la ~/Library/Developer/Xcode/DerivedData/BetterVoice-*/Build/Products/Debug/BetterVoice.app/Contents/Frameworks/libwhisper*
```

You should see:
```
libwhisper.1.8.0.dylib       # Real file
libwhisper.1.dylib -> ...    # Symlink (arrow indicates link)
```

### Clean rebuild

```bash
make clean
make build
```

## Development Workflow

Recommended workflow for development:

1. Make code changes in Xcode
2. Build: `⌘B` in Xcode or `make build` in terminal
3. Run: `⌘R` in Xcode or `make run` in terminal

The Makefile ensures the symlink is always created, preventing runtime errors.
