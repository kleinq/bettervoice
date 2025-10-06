# BetterVoice

macOS voice-to-text application with real-time transcription using Whisper.

## Features

- 🎤 **Push-to-talk recording** with customizable hotkeys
- 🧠 **Local AI transcription** using Whisper
- ✨ **Text enhancement** with context-aware formatting
- 📋 **Auto-paste** to any application
- 🔒 **Privacy-first** - all processing happens locally
- ⚙️ **Customizable settings** - hotkeys, audio input, models, and more

## Quick Start

### Building

```bash
# Clone the repository
git clone <repository-url>
cd bettervoice

# Build and run
make run
```

**Important:** Always use `make build` or `make run` to ensure proper library linking. See [docs/BUILDING.md](docs/BUILDING.md) for details.

### First Launch

1. **Permissions Setup** - On first launch, BetterVoice will guide you through:
   - Microphone access (required for recording)
   - Accessibility access (required for auto-paste)

2. **Recording** - Press `⌘R` (or your custom hotkey) to start recording, release to transcribe and paste

3. **Settings** - Access via menu bar icon:
   - Change hotkeys
   - Select audio input device
   - Download/select Whisper models
   - Configure cloud enhancement (optional)

## Development

See [docs/BUILDING.md](docs/BUILDING.md) for detailed build instructions and troubleshooting.

### Requirements

- macOS 12.0+
- Xcode 14.0+
- Swift 5.9+

### Project Structure

```
BetterVoice/
├── App/                    # App lifecycle and state
├── Views/                  # SwiftUI views
├── Services/              # Core services (audio, whisper, paste)
├── Models/                # Data models
└── Utilities/             # Helpers and extensions

scripts/                   # Build and setup scripts
docs/                      # Documentation
```

## License

[License details here]
