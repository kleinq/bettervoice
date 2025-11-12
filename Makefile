.PHONY: build run clean package release

DERIVED_DATA := $(shell find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "BetterVoice-*" -type d | head -n 1)
APP_PATH := $(DERIVED_DATA)/Build/Products/Debug/BetterVoice.app
FRAMEWORKS_DIR := $(APP_PATH)/Contents/Frameworks

build:
	@echo "🔨 Building BetterVoice..."
	@cd BetterVoice && xcodebuild -project BetterVoice.xcodeproj -scheme BetterVoice -configuration Debug
	@echo "\n🔧 Post-build: Fixing whisper library symlink..."
	@cd $(FRAMEWORKS_DIR) && \
		rm -f libwhisper.1.dylib 2>/dev/null || true && \
		ln -sf libwhisper.1.8.0.dylib libwhisper.1.dylib && \
		echo "✅ Created symlink: libwhisper.1.dylib -> libwhisper.1.8.0.dylib" && \
		ls -la libwhisper*
	@echo "\n✨ Build complete!"

run: build
	@echo "\n🚀 Launching BetterVoice..."
	@killall BetterVoice 2>/dev/null || true
	@open $(APP_PATH)

clean:
	@echo "🧹 Cleaning build artifacts..."
	@cd BetterVoice && xcodebuild -project BetterVoice.xcodeproj -scheme BetterVoice -configuration Debug clean
	@echo "✅ Clean complete!"

package:
	@echo "📦 Packaging BetterVoice for distribution..."
	@./scripts/package-app.sh

release:
	@echo "🚀 Building and packaging Release version..."
	@BUILD_CONFIG=Release ./scripts/package-app.sh

help:
	@echo "BetterVoice Makefile Commands:"
	@echo ""
	@echo "  make build    - Build the app in Debug mode"
	@echo "  make run      - Build and run the app"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make package  - Package the app for distribution (uses last build)"
	@echo "  make release  - Build Release version and create DMG"
	@echo "  make help     - Show this help message"
	@echo ""
