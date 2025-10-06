.PHONY: build run clean

DERIVED_DATA := /Users/robertwinder/Library/Developer/Xcode/DerivedData/BetterVoice-exfoadfrwnjtreabbnzxrlqupgxl
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
