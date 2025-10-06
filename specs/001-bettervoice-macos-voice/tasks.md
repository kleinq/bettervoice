# Tasks: BetterVoice Voice Transcription App

**Input**: Design documents from `/Users/robertwinder/Projects/hack/bettervoice/specs/001-bettervoice-macos-voice/`
**Prerequisites**: plan.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

## Path Conventions

This is a native macOS Xcode project with the following structure:
- **App code**: `BetterVoice/BetterVoice/` (Main app target)
- **Models**: `BetterVoice/BetterVoice/Models/`
- **Services**: `BetterVoice/BetterVoice/Services/`
- **Views**: `BetterVoice/BetterVoice/Views/`
- **Tests**: `BetterVoice/BetterVoiceTests/`
- **UI Tests**: `BetterVoice/BetterVoiceUITests/`

---

## Phase 3.1: Setup (5 tasks)

- [x] **T001** Create Xcode project `BetterVoice.xcodeproj` with macOS App template targeting macOS 12.0+
- [x] **T002** Add Swift Package Manager dependencies: GRDB.swift (v6.x) for SQLite database
- [x] **T003** Add whisper.cpp as git submodule in `BetterVoice/whisper.cpp/` and configure C++ bridging header
- [x] **T004** Configure Xcode project settings: Swift 5.9+, enable sandboxing, configure Info.plist with permission usage descriptions
- [x] **T005** [P] Setup SwiftLint configuration file `.swiftlint.yml` with project-specific rules

---

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3

**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

### Contract Tests (All [P] - Different files)

- [ ] **T006** [P] Contract test for AudioCaptureService in `BetterVoice/BetterVoiceTests/Contract/AudioCaptureContractTests.swift`
  - Test startCapture completes within 100ms (PR-001)
  - Test stopCapture returns PCM16 data
  - Test audioLevelPublisher emits while capturing
  - Test error cases (permission denied, already capturing, not capturing)

- [ ] **T007** [P] Contract test for WhisperService in `BetterVoice/BetterVoiceTests/Contract/WhisperServiceContractTests.swift`
  - Test loadModel succeeds for valid model
  - Test transcribe returns text for valid audio
  - Test transcription meets <3s performance requirement (PR-002)
  - Test error cases (model not loaded, invalid audio, cancelled)

- [ ] **T008** [P] Contract test for TextEnhancementService in `BetterVoice/BetterVoiceTests/Contract/TextEnhancementContractTests.swift`
  - Test enhance removes filler words
  - Test enhance formats by document type (email, message, document, search)
  - Test enhance applies learning patterns
  - Test enhance uses cloud API when enabled with fallback

- [ ] **T009** [P] Contract test for HotkeyManager in `BetterVoice/BetterVoiceTests/Contract/HotkeyContractTests.swift`
  - Test register hotkey succeeds
  - Test onKeyPress callback fires on key press
  - Test onKeyRelease callback fires on key release
  - Test unregister cleans up hotkey

- [ ] **T010** [P] Contract test for PasteService in `BetterVoice/BetterVoiceTests/Contract/PasteContractTests.swift`
  - Test paste completes within 500ms (PR-003)
  - Test paste copies to clipboard
  - Test paste simulates Cmd+V CGEvent
  - Test paste handles no active text field

- [ ] **T011** [P] Contract test for DocumentTypeDetector in `BetterVoice/BetterVoiceTests/Contract/DocumentTypeDetectorContractTests.swift`
  - Test detects email from Mail.app bundle ID
  - Test detects email from Gmail URL
  - Test detects message from Slack bundle ID
  - Test fallback NLP detection for unknown apps
  - Test achieves >85% accuracy goal (QR-002)

- [ ] **T012** [P] Contract test for LearningService in `BetterVoice/BetterVoiceTests/Contract/LearningContractTests.swift`
  - Test observe monitors clipboard for edits
  - Test findSimilarPatterns uses edit distance matching
  - Test applyLearned modifies text based on patterns
  - Test pattern storage in SQLite database

### Integration Tests (All [P] - Different files)

- [ ] **T013** [P] Integration test for end-to-end transcription workflow in `BetterVoice/BetterVoiceTests/Integration/EndToEndTranscriptionTests.swift`
  - Test complete flow: hotkey → capture → transcribe → enhance → paste
  - Test flow completes within total time budget (<20s for 15s audio)
  - Test final text appears in clipboard with proper formatting
  - Based on quickstart.md primary scenario

- [ ] **T014** [P] Integration test for learning system in `BetterVoice/BetterVoiceTests/Integration/LearningSystemTests.swift`
  - Test transcription → paste → edit detection → pattern storage
  - Test pattern application on subsequent transcriptions
  - Test confidence increases with frequency
  - Test demonstrates QR-004 (reduction in user edits over time)

- [ ] **T015** [P] Integration test for cloud API enhancement in `BetterVoice/BetterVoiceTests/Integration/CloudAPIIntegrationTests.swift`
  - Test Claude API enhancement (mock API)
  - Test OpenAI API enhancement (mock API)
  - Test fallback to local-only on API failure
  - Test timeout handling (30s)

- [ ] **T016** [P] Integration test for hotkey workflow in `BetterVoice/BetterVoiceTests/Integration/HotkeyWorkflowTests.swift`
  - Test hotkey press starts recording
  - Test hotkey release stops recording
  - Test visual feedback updates (menu bar icon, overlay)
  - Test audio cues play at correct times

### Unit Tests for Models (All [P] - Different files)

- [x] **T017** [P] Unit tests for AudioRecording model in `BetterVoice/BetterVoiceTests/Unit/Models/AudioRecordingTests.swift`
- [x] **T018** [P] Unit tests for TranscriptionJob model in `BetterVoice/BetterVoiceTests/Unit/Models/TranscriptionJobTests.swift`
- [x] **T019** [P] Unit tests for EnhancedText model in `BetterVoice/BetterVoiceTests/Unit/Models/EnhancedTextTests.swift`
- [x] **T020** [P] Unit tests for DocumentTypeContext model in `BetterVoice/BetterVoiceTests/Unit/Models/DocumentTypeContextTests.swift`
- [x] **T021** [P] Unit tests for LearningPattern model in `BetterVoice/BetterVoiceTests/Unit/Models/LearningPatternTests.swift`
- [x] **T022** [P] Unit tests for WhisperModel model in `BetterVoice/BetterVoiceTests/Unit/Models/WhisperModelTests.swift`
- [x] **T023** [P] Unit tests for UserPreferences model in `BetterVoice/BetterVoiceTests/Unit/Models/UserPreferencesTests.swift`
- [x] **T024** [P] Unit tests for ExternalLLMConfig model in `BetterVoice/BetterVoiceTests/Unit/Models/ExternalLLMConfigTests.swift`

---

## Phase 3.3: Core Implementation (ONLY after tests are failing)

### Models (All [P] - Different files, implement to make unit tests pass)

- [x] **T025** [P] Implement AudioRecording model in `BetterVoice/BetterVoice/Models/AudioRecording.swift`
  - Codable struct with id, timestamp, duration, sampleRate, channels, format, filePath, fileSize, deviceName, deviceUID
  - Validation: duration ≤7200s, sampleRate==16000, channels==1, format=="PCM16"

- [x] **T026** [P] Implement TranscriptionJob model in `BetterVoice/BetterVoice/Models/TranscriptionJob.swift`
  - Codable struct with id, audioRecordingID, modelSize, detectedLanguage, status, timestamps, rawTranscription, error
  - Enums: WhisperModelSize, TranscriptionStatus
  - Computed properties: processingDuration, isComplete

- [x] **T027** [P] Implement EnhancedText model in `BetterVoice/BetterVoice/Models/EnhancedText.swift`
  - Codable struct with transcriptionJobID, documentTypeContextID, originalText, enhancedText, metadata
  - Arrays: appliedRules, removedFillers, formattingChanges
  - Computed property: improvementRatio

- [x] **T028** [P] Implement DocumentTypeContext model in `BetterVoice/BetterVoice/Models/DocumentTypeContext.swift`
  - Codable struct with appBundleID, appName, windowTitle, url, detectedType, detectionMethod, confidence
  - Enums: DocumentType (.email, .message, .document, .searchQuery, .unknown), DetectionMethod
  - Computed property: isConfident (confidence ≥ 0.85)

- [x] **T029** [P] Implement LearningPattern model in `BetterVoice/BetterVoice/Models/LearningPattern.swift`
  - Codable struct conforming to GRDB FetchableRecord, PersistableRecord
  - Fields: id, documentType, originalText, editedText, editDistance, frequency, firstSeen, lastSeen, confidence
  - Computed properties: isTrusted, isSignificantEdit
  - Database table name: "learning_patterns"

- [x] **T030** [P] Implement WhisperModel model in `BetterVoice/BetterVoice/Models/WhisperModel.swift`
  - Codable struct with size, fileName, fileSize, storageURL, isDownloaded, checksumSHA256
  - Static constants for model sizes (tiny: 75MB, base: 142MB, small: 466MB, medium: 1.5GB, large: 2.9GB)
  - Computed properties: displaySize, needsDownload

- [x] **T031** [P] Implement UserPreferences model in `BetterVoice/BetterVoice/Models/UserPreferences.swift`
  - Codable struct with hotkey settings, selectedModelSize, audio settings, learning/cloud toggles, log level
  - Default values per data-model.md
  - Methods: save() to UserDefaults, static load() from UserDefaults
  - Enum: LogLevel (.debug, .info, .warning, .error)

- [x] **T032** [P] Implement ExternalLLMConfig model in `BetterVoice/BetterVoice/Models/ExternalLLMConfig.swift`
  - Codable struct with provider, isEnabled, apiKeyKeychainItem, endpoint, model, systemPrompts
  - Dictionary: systemPrompts per DocumentType
  - Static defaultSystemPrompts per document type
  - Computed property: isConfigured (checks Keychain)

### Storage Services (Sequential - Database setup required first)

- [x] **T033** Implement DatabaseManager in `BetterVoice/BetterVoice/Services/Storage/DatabaseManager.swift`
  - GRDB DatabaseQueue initialization
  - Create learning_patterns table with schema from data-model.md
  - Migration support for schema updates
  - Database path: ~/Library/Application Support/BetterVoice/learning.db

- [x] **T034** Implement PreferencesStore in `BetterVoice/BetterVoice/Services/Storage/PreferencesStore.swift`
  - Wrapper around UserPreferences model
  - Thread-safe access to UserDefaults
  - Observation support for preferences changes

- [x] **T035** Implement ModelStorage in `BetterVoice/BetterVoice/Services/Storage/ModelStorage.swift`
  - Manage Whisper model files in ~/Library/Application Support/BetterVoice/models/
  - List available models, check if downloaded
  - Delete model files for cleanup

### Utility Services (All [P] - Different files)

- [x] **T036** [P] Implement Logger in `BetterVoice/BetterVoice/Utilities/Logger.swift`
  - Wrapper around os_log (OSLog)
  - File logging to ~/Library/Logs/BetterVoice/
  - Log rotation, configurable log level from UserPreferences
  - Methods: debug(), info(), warning(), error()

- [x] **T037** [P] Implement ErrorHandler in `BetterVoice/BetterVoice/Utilities/ErrorHandler.swift`
  - Central error handling and user-facing error messages
  - Localized error descriptions (per spec SR-007, UR-003)
  - Error reporting to Logger

- [x] **T038** [P] Implement KeychainHelper in `BetterVoice/BetterVoice/Utilities/KeychainHelper.swift`
  - Store API keys in macOS Keychain (kSecAttrService = "com.bettervoice.apikeys")
  - Methods: store(key:item:), retrieve(item:), delete(item:)
  - Secure, app-only access per SR-003

### Audio Services

- [x] **T039** Implement AudioCaptureService in `BetterVoice/BetterVoice/Services/Audio/AudioCaptureService.swift`
  - Conform to AudioCaptureServiceProtocol (from contract)
  - Use AVAudioEngine for capture, AVAudioConverter for PCM16 format
  - Methods: startCapture(deviceUID:), stopCapture() → Data
  - Publisher: audioLevelPublisher (60Hz updates)
  - Meets <100ms start latency (PR-001)

- [x] **T040** Implement AudioProcessingService in `BetterVoice/BetterVoice/Services/Audio/AudioProcessingService.swift`
  - Audio format conversion utilities
  - Waveform generation for visualization
  - Audio file I/O for temporary storage

### Transcription Services

- [x] **T041** Implement WhisperService in `BetterVoice/BetterVoice/Services/Transcription/WhisperService.swift`
  - Conform to WhisperServiceProtocol (from contract)
  - C++ bridging to whisper.cpp library
  - Methods: loadModel(_:), transcribe(audioData:) → TranscriptionResult
  - Async processing on background queue
  - Meets <3s transcription for 30s audio with base model (PR-002)

- [x] **T042** Implement ModelDownloadService in `BetterVoice/BetterVoice/Services/Transcription/ModelDownloadService.swift`
  - Download Whisper models from Hugging Face or official sources
  - Progress tracking via URLSession delegate
  - SHA256 checksum validation
  - Auto-download on first model selection (FR-005)

- [x] **T043** Implement TranscriptionQueue in `BetterVoice/BetterVoice/Services/Transcription/TranscriptionQueue.swift`
  - Queue management for transcription jobs
  - Serial processing (one at a time to avoid CPU saturation)
  - Priority queue support for user-initiated transcriptions

### Enhancement Services

- [x] **T044** Implement TextEnhancementService in `BetterVoice/BetterVoice/Services/Enhancement/TextEnhancementService.swift`
  - Conform to TextEnhancementServiceProtocol (from contract)
  - 6-stage enhancement pipeline per research.md
  - Method: enhance(text:documentType:applyLearning:useCloud:) → EnhancedText
  - Coordinate FillerWordRemover, FormatApplier, LearningService, LLMEnhancementService

- [x] **T045** Implement DocumentTypeDetector in `BetterVoice/BetterVoice/Services/Enhancement/DocumentTypeDetector.swift`
  - Use NSWorkspace.shared.frontmostApplication for bundle ID
  - Bundle ID → DocumentType mapping
  - URL analysis for browser apps (Gmail, Google Docs)
  - NLP fallback pattern matching
  - Target >85% accuracy (QR-002)

- [x] **T046** Implement FillerWordRemover in `BetterVoice/BetterVoice/Services/Enhancement/FillerWordRemover.swift`
  - Pattern-based removal: "um", "uh", "like", "you know", "I mean", "basically", "actually"
  - Context-aware (don't remove "like" in comparisons)
  - Return list of removed fillers for metadata

- [x] **T047** Implement FormatApplier in `BetterVoice/BetterVoice/Services/Enhancement/FormatApplier.swift`
  - Document-type-specific formatting rules
  - Email: greeting, closing, paragraphs, name capitalization
  - Message: casual tone, minimal punctuation, emoji support
  - Document: lists, headings, paragraphs, professional tone
  - SearchQuery: keyword extraction, concise output

### Learning Services

- [x] **T048** Implement LearningService in `BetterVoice/BetterVoice/Services/Learning/LearningService.swift`
  - Conform to LearningServiceProtocol (from contract)
  - Methods: observe(originalText:documentType:), findSimilarPatterns(), applyLearned()
  - Edit distance calculation (Levenshtein)
  - GRDB queries to learning_patterns table
  - Pattern matching threshold: 0.8 similarity

- [x] **T049** Implement PatternRecognizer in `BetterVoice/BetterVoice/Services/Learning/PatternRecognizer.swift`
  - Identify recurring editing patterns
  - Calculate confidence based on frequency
  - Prune low-confidence patterns (< 0.3) after 30 days

- [x] **T050** Implement ClipboardMonitor in `BetterVoice/BetterVoice/Services/Learning/ClipboardMonitor.swift`
  - Monitor NSPasteboard for changes after paste
  - 10-second observation window per FR-017
  - Detect user edits via clipboard diff
  - Notify LearningService of significant edits (>10% change)

### Cloud API Services (Both [P] - Different files, independent implementations)

- [x] **T051** [P] Implement ClaudeAPIClient in `BetterVoice/BetterVoice/Services/Cloud/ClaudeAPIClient.swift`
  - Conform to LLMProvider protocol
  - Anthropic Claude API via URLSession
  - Method: enhance(text:documentType:systemPrompt:) async throws → String
  - Timeout: 30s (configurable)
  - HTTPS with certificate validation (SR-008)

- [x] **T052** [P] Implement OpenAIAPIClient in `BetterVoice/BetterVoice/Services/Cloud/OpenAIAPIClient.swift`
  - Conform to LLMProvider protocol
  - OpenAI Completion API via URLSession
  - Method: enhance(text:documentType:systemPrompt:) async throws → String
  - Timeout: 30s (configurable)
  - HTTPS with certificate validation (SR-008)

- [x] **T053** Implement LLMEnhancementService in `BetterVoice/BetterVoice/Services/Cloud/LLMEnhancementService.swift`
  - Coordinate Claude and OpenAI clients
  - Load API key from Keychain via KeychainHelper
  - Provider selection based on UserPreferences
  - Fallback to local-only on failure

### System Services

- [x] **T054** Implement HotkeyManager in `BetterVoice/BetterVoice/Services/System/HotkeyManager.swift`
  - Conform to HotkeyManagerProtocol (from contract)
  - Use Carbon Events API (RegisterEventHotKey)
  - Callbacks: onKeyPress, onKeyRelease
  - User-configurable hotkey from UserPreferences
  - <100ms response time (PR-001)

- [x] **T055** Implement PasteService in `BetterVoice/BetterVoice/Services/System/PasteService.swift`
  - Conform to PasteServiceProtocol (from contract)
  - Copy text to NSPasteboard
  - Simulate Cmd+V via CGEvent
  - <500ms paste operation (PR-003)
  - Handle no active text field case

- [x] **T056** Implement AppDetectionService in `BetterVoice/BetterVoice/Services/System/AppDetectionService.swift`
  - Use NSWorkspace.shared.frontmostApplication
  - Extract bundle ID, app name, window title
  - URL extraction for browser apps via Accessibility API (AXUIElement)
  - Return DocumentTypeContext

- [x] **T057** Implement PermissionsManager in `BetterVoice/BetterVoice/Services/System/PermissionsManager.swift`
  - Check microphone, accessibility, screen recording permissions
  - Request permissions with clear justifications (UR-006)
  - Status tracking and UI updates
  - Permissions required: AVCaptureDevice (mic), AXIsProcessTrusted (accessibility), CGWindowListCopyWindowInfo (screen recording)

### App State & Coordination

- [x] **T058** Implement AppState in `BetterVoice/BetterVoice/App/AppState.swift`
  - ObservableObject for global app state
  - Current status: .ready, .recording, .transcribing, .enhancing, .pasting, .error
  - Coordinate services: HotkeyManager, AudioCaptureService, WhisperService, etc.
  - Workflow orchestration per quickstart.md

- [x] **T059** Implement BetterVoiceApp in `BetterVoice/BetterVoice/App/BetterVoiceApp.swift`
  - SwiftUI App entry point
  - Initialize AppState, load default Whisper model
  - Setup menu bar app (LSUIElement = YES in Info.plist)
  - App launch <2s (PR-004)

---

## Phase 3.4: Views (SwiftUI UI Implementation)

### Menu Bar Views (Both [P])

- [x] **T060** [P] Implement MenuBarView in `BetterVoice/BetterVoice/Views/MenuBar/MenuBarView.swift`
  - NSMenu integration with SwiftUI
  - Menu items: Status display, Start/Stop recording (manual), Settings, View Logs, About, Quit
  - Observe AppState for status updates

- [x] **T061** [P] Implement StatusIconView in `BetterVoice/BetterVoice/Views/MenuBar/StatusIconView.swift`
  - Menu bar icon with state-based colors
  - States: ready (white), recording (red), processing (yellow), pasting (green), error (warning)
  - Icon images in Assets.xcassets

### Settings Window Views (All [P] - Different tab files)

- [x] **T062** [P] Implement SettingsWindow in `BetterVoice/BetterVoice/Views/Settings/SettingsView.swift`
  - SwiftUI window with TabView
  - 6 tabs: Recording, Transcription, Enhancement, External LLM, Advanced, Permissions
  - Window size: ~600x500, non-resizable

- [x] **T063** [P] Implement RecordingTab in `BetterVoice/BetterVoice/Views/Settings/RecordingTab.swift`
  - Hotkey configuration with key capture button
  - Audio input device selection (AVFoundation devices)
  - Audio feedback toggle, visual overlay toggle

- [x] **T064** [P] Implement TranscriptionTab in `BetterVoice/BetterVoice/Views/Settings/TranscriptionTab.swift`
  - Whisper model selection dropdown (tiny, base, small, medium, large)
  - Model download status indicators
  - Download buttons for missing models
  - Model storage location display
  - Language preference (auto-detect default)

- [x] **T065** [P] Implement EnhancementTab in `BetterVoice/BetterVoice/Views/Settings/EnhancementTab.swift`
  - Document type preferences (email, message, document, search)
  - Custom format rules editor (optional)
  - Learning system toggle

- [x] **T066** [P] Implement ExternalLLMTab in `BetterVoice/BetterVoice/Views/Settings/ExternalLLMTab.swift`
  - Enable/disable toggle
  - Provider selection (Claude vs OpenAI)
  - Secure API key input (SecureField)
  - System prompt editor per document type
  - Test connection button

- [x] **T067** [P] Implement AdvancedTab in `BetterVoice/BetterVoice/Views/Settings/AdvancedTab.swift`
  - Log level selection (debug, info, warning, error)
  - Log file location display
  - Clear logs button
  - Learning database location, reset learning button
  - Data export/import buttons

- [x] **T068** [P] Implement PermissionsTab in `BetterVoice/BetterVoice/Views/Settings/PermissionsTab.swift`
  - Microphone access status indicator
  - Accessibility access status indicator
  - Screen recording access status indicator
  - Request permissions buttons with open System Settings links

### Overlay Views (Both [P])

- [x] **T069** [P] Implement RecordingOverlay in `BetterVoice/BetterVoice/Views/Overlays/RecordingOverlay.swift`
  - Semi-transparent HUD window
  - Waveform visualization (use WaveformView component)
  - Timer display (MM:SS format)
  - "Recording..." label
  - Pulse animation
  - Position: bottom-right corner (NSWindow positioning)

- [x] **T070** [P] Implement ProcessingOverlay in `BetterVoice/BetterVoice/Views/Overlays/ProcessingOverlay.swift`
  - Semi-transparent HUD window
  - Progress indicator (ProgressIndicatorView component)
  - Status text: "Transcribing..." → "Enhancing..." → "Pasting..."
  - Estimated time remaining display
  - Position: bottom-right corner

### Component Views (Both [P])

- [x] **T071** [P] Implement WaveformView in `BetterVoice/BetterVoice/Views/Components/WaveformView.swift`
  - Real-time waveform visualization from audio levels
  - Subscribe to AudioCaptureService.audioLevelPublisher
  - Smooth animation at 60Hz
  - Bar graph style

- [x] **T072** [P] Implement ProgressIndicatorView in `BetterVoice/BetterVoice/Views/Components/ProgressIndicatorView.swift`
  - Circular or linear progress indicator
  - Indeterminate mode for transcription
  - Determinate mode for long audio (subscribe to WhisperService.progressPublisher)

---

## Phase 3.5: Integration & Wiring

- [x] **T073** Wire up hotkey → recording workflow in AppState
  - HotkeyManager.onKeyPress → AudioCaptureService.startCapture()
  - HotkeyManager.onKeyRelease → AudioCaptureService.stopCapture() → TranscriptionQueue

- [x] **T074** Wire up transcription → enhancement → paste workflow in AppState
  - WhisperService.transcribe() → TextEnhancementService.enhance() → PasteService.paste()
  - Update menu bar icon and overlays at each stage

- [x] **T075** Wire up learning system observation in AppState
  - After paste, LearningService.observe() with ClipboardMonitor
  - Store patterns in database via DatabaseManager

- [x] **T076** Integrate PermissionsManager with app launch flow
  - Check permissions on first launch
  - Show permission request UI if needed
  - Block recording if microphone denied

- [x] **T077** Connect Settings window to UserPreferences changes
  - Two-way binding between SwiftUI views and PreferencesStore
  - Observe preference changes and update services (e.g., hotkey, model selection)

---

## Phase 3.6: Resources & Assets

- [x] **T078** [P] Add audio cue sound files to `BetterVoice/BetterVoice/Resources/Sounds/`
  - IMPLEMENTED: Using macOS system sounds via SoundPlayer.swift
  - recording-start: "Ping" system sound
  - recording-stop: "Pop" system sound
  - processing-complete: "Morse" system sound
  - error: "Basso" system sound

- [x] **T079** [P] Design and add menu bar icons to `BetterVoice/BetterVoice/Resources/Assets.xcassets/`
  - IMPLEMENTED: Using SF Symbols in StatusIconView.swift
  - icon-ready: "mic" symbol
  - icon-recording: "mic.fill" symbol (red)
  - icon-processing: "waveform" symbol (yellow)
  - icon-pasting: "arrow.down.doc" symbol (green)
  - icon-error: "exclamationmark.triangle" symbol (red)

---

## Phase 3.7: Polish & Quality

### Unit Tests for Services (All [P])

- [ ] **T080** [P] Unit tests for AudioCaptureService in `BetterVoice/BetterVoiceTests/Unit/Services/AudioCaptureServiceTests.swift`
- [ ] **T081** [P] Unit tests for WhisperService in `BetterVoice/BetterVoiceTests/Unit/Services/WhisperServiceTests.swift`
- [ ] **T082** [P] Unit tests for TextEnhancementService in `BetterVoice/BetterVoiceTests/Unit/Services/TextEnhancementServiceTests.swift`
- [ ] **T083** [P] Unit tests for FillerWordRemover in `BetterVoice/BetterVoiceTests/Unit/Services/FillerWordRemoverTests.swift`
- [ ] **T084** [P] Unit tests for DocumentTypeDetector in `BetterVoice/BetterVoiceTests/Unit/Services/DocumentTypeDetectorTests.swift`
- [ ] **T085** [P] Unit tests for LearningService in `BetterVoice/BetterVoiceTests/Unit/Services/LearningServiceTests.swift`
- [ ] **T086** [P] Unit tests for utilities (Logger, ErrorHandler, KeychainHelper) in `BetterVoice/BetterVoiceTests/Unit/Utilities/`

### UI Tests (All [P])

- [ ] **T087** [P] UI tests for menu bar interaction in `BetterVoice/BetterVoiceUITests/MenuBarUITests.swift`
  - Test menu bar icon click opens menu
  - Test menu items are accessible
  - Test status text updates

- [ ] **T088** [P] UI tests for settings window in `BetterVoice/BetterVoiceUITests/SettingsUITests.swift`
  - Test all tabs are accessible
  - Test hotkey configuration
  - Test model download button
  - Test API key input

- [ ] **T089** [P] UI tests for overlays in `BetterVoice/BetterVoiceUITests/OverlayUITests.swift`
  - Test recording overlay appears on recording
  - Test processing overlay appears after recording
  - Test overlays dismiss appropriately

### Performance & Validation

- [ ] **T090** Performance test: Verify hotkey response <100ms (PR-001)
  - Measure time from key press to AudioCaptureService.startCapture()

- [ ] **T091** Performance test: Verify transcription <3s for 30s audio with base model (PR-002)
  - Measure WhisperService.transcribe() duration

- [ ] **T092** Performance test: Verify paste <500ms (PR-003)
  - Measure PasteService.paste() duration

- [ ] **T093** Performance test: Verify app launch <2s (PR-004)
  - Measure time from app launch to ready state

- [ ] **T094** Performance test: Verify UI frame time <16ms (PR-008)
  - Use Instruments to measure SwiftUI view rendering

- [ ] **T095** Memory test: Verify typical usage <200MB, max <500MB (FR-028)
  - Use Instruments to profile memory during transcription

- [ ] **T096** CPU test: Verify sustained CPU <50% (FR-027)
  - Monitor CPU usage during transcription

- [ ] **T097** Run complete quickstart.md end-to-end validation
  - Execute primary user scenario manually
  - Verify all acceptance criteria met

- [ ] **T098** Code quality: Run SwiftLint and fix warnings/errors

- [ ] **T099** Error handling audit: Verify all error cases have user-friendly messages (UR-003)

- [ ] **T100** Accessibility audit: Test with VoiceOver and verify macOS accessibility standards

---

## Dependencies

**Setup before everything**: T001-T005

**Tests before implementation (TDD)**:
- T006-T024 (all tests) before T025-T072 (implementation)

**Model dependencies**:
- T025-T032 (models) can run in parallel, block services

**Service dependencies**:
- T033 (DatabaseManager) blocks T048 (LearningService)
- T036-T038 (utilities) block services that use them
- T039 (AudioCaptureService) blocks T073 (workflow wiring)
- T041 (WhisperService) blocks T074 (workflow wiring)
- T044 (TextEnhancementService) blocks T074 (workflow wiring)
- T055 (PasteService) blocks T074 (workflow wiring)

**View dependencies**:
- T058-T059 (AppState, App) before T060-T072 (views)
- T060-T072 (views) can mostly run in parallel

**Integration before polish**:
- T073-T077 (integration) before T080-T100 (polish)

---

## Parallel Execution Examples

### Contract Tests (T006-T012):
```swift
// All contract tests can run in parallel (different files)
Task: "Write contract test for AudioCaptureService in BetterVoiceTests/Contract/AudioCaptureContractTests.swift"
Task: "Write contract test for WhisperService in BetterVoiceTests/Contract/WhisperServiceContractTests.swift"
Task: "Write contract test for TextEnhancementService in BetterVoiceTests/Contract/TextEnhancementContractTests.swift"
Task: "Write contract test for HotkeyManager in BetterVoiceTests/Contract/HotkeyContractTests.swift"
Task: "Write contract test for PasteService in BetterVoiceTests/Contract/PasteContractTests.swift"
Task: "Write contract test for DocumentTypeDetector in BetterVoiceTests/Contract/DocumentTypeDetectorContractTests.swift"
Task: "Write contract test for LearningService in BetterVoiceTests/Contract/LearningContractTests.swift"
```

### Model Implementation (T025-T032):
```swift
// All models can be implemented in parallel (different files)
Task: "Implement AudioRecording model in BetterVoice/Models/AudioRecording.swift"
Task: "Implement TranscriptionJob model in BetterVoice/Models/TranscriptionJob.swift"
Task: "Implement EnhancedText model in BetterVoice/Models/EnhancedText.swift"
Task: "Implement DocumentTypeContext model in BetterVoice/Models/DocumentTypeContext.swift"
Task: "Implement LearningPattern model in BetterVoice/Models/LearningPattern.swift"
Task: "Implement WhisperModel model in BetterVoice/Models/WhisperModel.swift"
Task: "Implement UserPreferences model in BetterVoice/Models/UserPreferences.swift"
Task: "Implement ExternalLLMConfig model in BetterVoice/Models/ExternalLLMConfig.swift"
```

### Settings Tabs (T063-T068):
```swift
// All settings tabs can be implemented in parallel (different files)
Task: "Implement RecordingTab in BetterVoice/Views/Settings/RecordingTab.swift"
Task: "Implement TranscriptionTab in BetterVoice/Views/Settings/TranscriptionTab.swift"
Task: "Implement EnhancementTab in BetterVoice/Views/Settings/EnhancementTab.swift"
Task: "Implement ExternalLLMTab in BetterVoice/Views/Settings/ExternalLLMTab.swift"
Task: "Implement AdvancedTab in BetterVoice/Views/Settings/AdvancedTab.swift"
Task: "Implement PermissionsTab in BetterVoice/Views/Settings/PermissionsTab.swift"
```

### Cloud API Clients (T051-T052):
```swift
// Both cloud API clients can be implemented in parallel (different files, different providers)
Task: "Implement ClaudeAPIClient in BetterVoice/Services/Cloud/ClaudeAPIClient.swift"
Task: "Implement OpenAIAPIClient in BetterVoice/Services/Cloud/OpenAIAPIClient.swift"
```

---

## Notes

- [P] tasks = different files, no dependencies, can run in parallel
- Verify all tests fail before implementing (Red-Green-Refactor)
- Commit after each task completion
- Focus on making tests pass with minimal code, then refactor
- Constitution principles enforced throughout: TDD, privacy, performance, native integration

---

## Validation Checklist

- [x] All 3 contracts have corresponding tests (T006-T012)
- [x] All 8 entities have model tasks (T025-T032)
- [x] All tests come before implementation (Phase 3.2 before 3.3)
- [x] Parallel tasks are truly independent (different files)
- [x] Each task specifies exact file path
- [x] No task modifies same file as another [P] task
- [x] TDD ordering: Setup → Tests → Models → Services → Views → Integration → Polish
- [x] Total: 100 tasks across 7 phases
