# Quickstart Guide: BetterVoice End-to-End User Flow

**Feature**: BetterVoice Voice Transcription App
**Purpose**: Step-by-step validation of primary user scenario
**Date**: 2025-09-30

## Prerequisites

**System Requirements**:
- macOS 12.0 (Monterey) or later
- 8GB RAM minimum (16GB recommended for large models)
- 5GB free disk space
- Microphone connected

**Permissions Required**:
1. Microphone access - Audio recording
2. Accessibility access - Hotkey detection and text pasting
3. Screen Recording - Active application detection

**Initial Setup**:
- BetterVoice.app installed in /Applications
- App launched for first time
- Permissions granted via System Settings
- At least one Whisper model downloaded (base recommended)

## Primary User Flow: Email Transcription

### Scenario
User is composing an email in Gmail (Chrome browser) and wants to quickly add a spoken paragraph about meeting details without typing.

### Step-by-Step Walkthrough

#### 1. App Launch & Ready State

**User Action**: Open BetterVoice from Applications folder

**Expected Behavior**:
- Menu bar icon appears (white circle ⚪)
- App launches in <2 seconds (PR-004)
- Default whisper model (base) auto-loads on launch
- Status: "Ready to record"

**Validation**:
```swift
// Integration Test
func testAppLaunchAndReadyState() async throws {
    // When
    let app = XCUIApplication()
    let launchStart = Date()
    app.launch()
    let launchTime = Date().timeIntervalSince(launchStart)

    // Then
    XCTAssertLessThan(launchTime, 2.0, "App must launch within 2s (PR-004)")
    XCTAssertTrue(app.menuBars.statusItems["BetterVoice"].exists)
    XCTAssertEqual(app.statusItem.icon, .ready)  // White circle
}
```

---

#### 2. Navigate to Gmail

**User Action**:
- Open Chrome
- Navigate to gmail.com
- Click "Compose" to start new email
- Click in email body field
- Cursor is blinking in body field

**Expected Behavior**:
- BetterVoice remains in background (menu bar only)
- No visible changes in BetterVoice
- Gmail is frontmost application

**Validation**:
- NSWorkspace.shared.frontmostApplication.bundleIdentifier == "com.google.Chrome"
- Active window URL contains "mail.google.com"

---

#### 3. Press and Hold Hotkey

**User Action**: Press and hold Right Option key while speaking:
> "Hi Sarah, I wanted to follow up on our meeting yesterday. We discussed the Q4 roadmap and I think we should schedule a follow-up for next week. Let me know what times work for you. Thanks."

*Duration: ~15 seconds*

**Expected Behavior** (FR-001, FR-010, FR-013, FR-014, PR-001):

**< 100ms after key press** (PR-001):
- Menu bar icon changes to red (🔴)
- Recording overlay appears bottom-right corner
- Overlay shows:
  - "Recording..." label
  - Waveform visualization (live audio level)
  - Timer starting at 0:00
  - Pulse animation
- Audio cue plays: subtle "ping" sound
- Microphone LED activates (hardware-dependent)

**During recording** (15 seconds):
- Waveform animates with user's voice
- Timer increments: 0:01, 0:02... 0:15
- Menu bar icon pulses red
- Audio captured continuously to memory buffer

**Expected State**:
```swift
// Internal state during recording
AudioCaptureService.isCapturing == true
AppState.currentStatus == .recording
HotkeyManager.keyCurrentlyPressed == true
AudioCaptureService.audioLevelPublisher emitting ~60Hz
```

**Validation**:
```swift
func testRecordingStartsWithin100ms() async throws {
    // Given
    let app = XCUIApplication()
    app.launch()
    let hotkeyStart = Date()

    // When
    app.pressHotkey(.rightOption)
    let overlayAppeared = app.overlays["RecordingOverlay"].waitForExistence(timeout: 0.1)
    let elapsed = Date().timeIntervalSince(hotkeyStart)

    // Then
    XCTAssertTrue(overlayAppeared)
    XCTAssertLessThan(elapsed, 0.1, "Recording must start within 100ms (PR-001)")
    XCTAssertEqual(app.statusItem.icon, .recording)  // Red
}
```

---

#### 4. Release Hotkey

**User Action**: Release Right Option key after speaking

**Expected Behavior** (FR-002, FR-011):

**Immediately on release** (<50ms):
- Recording stops
- Audio cue plays: subtle "pong" sound
- Overlay transitions to "Processing..." state
- Menu bar icon changes to yellow (🟡)
- Timer freezes at final duration (0:15)

**Processing overlay shows**:
- Progress spinner
- Status text: "Transcribing..."
- Estimated time: "~5 seconds"

**Expected State**:
```swift
AudioCaptureService.isCapturing == false
let audioData: Data = AudioCaptureService.lastCapturedAudio  // PCM16, ~480KB for 15s
AppState.currentStatus == .transcribing
TranscriptionJob.status == .queued → .transcribing
```

**Validation**:
```swift
func testRecordingStopsImmediately() async throws {
    // Given
    let app = XCUIApplication()
    app.pressHotkey(.rightOption)
    try await Task.sleep(nanoseconds: 1_000_000_000)  // Record 1s

    // When
    let releaseStart = Date()
    app.releaseHotkey(.rightOption)
    let processingAppeared = app.overlays["ProcessingOverlay"].waitForExistence(timeout: 0.1)
    let elapsed = Date().timeIntervalSince(releaseStart)

    // Then
    XCTAssertTrue(processingAppeared)
    XCTAssertLessThan(elapsed, 0.05, "Stop must be immediate (<50ms)")
    XCTAssertEqual(app.statusItem.icon, .processing)  // Yellow
}
```

---

#### 5. Transcription Phase

**Background Processing** (2-3 seconds for 15s audio with base model):

**5a. Whisper Transcription**:
- WhisperService receives PCM16 audio data
- Base model processes audio
- Language detection: "en" (English) with 0.98 confidence
- Raw output: "hi sarah i wanted to follow up on our meeting yesterday we discussed the q4 roadmap and i think we should schedule a follow up for next week let me know what times work for you thanks"

**Processing overlay updates**:
- Status: "Transcribing..." → "Enhancing..." (after 2s)

**Expected Performance**:
- Transcription completes in < 3 seconds (PR-002)
- Memory usage < 500MB (FR-028)
- CPU spikes to 80-100% briefly, average <50% (FR-027)
- UI remains responsive (frame time <16ms, PR-008)

**Validation**:
```swift
func testTranscriptionMeetsPerformanceRequirements() async throws {
    // Given
    let service = WhisperService()
    try await service.loadModel(WhisperModel.base)
    let audioData = captureTestAudio(duration: 15.0)

    // When
    let startMemory = ProcessInfo.processInfo.physicalMemory
    let startTime = Date()
    let result = try await service.transcribe(audioData: audioData)
    let elapsed = Date().timeIntervalSince(startTime)
    let endMemory = ProcessInfo.processInfo.physicalMemory

    // Then
    XCTAssertLessThan(elapsed, 3.0, "Must complete in <3s (PR-002)")
    XCTAssertLessThan(endMemory - startMemory, 500_000_000, "Memory <500MB (FR-028)")
    XCTAssertFalse(result.text.isEmpty)
}
```

---

#### 6. Enhancement Phase

**Background Processing** (<1 second):

**6a. Document Type Detection**:
- AppDetectionService queries NSWorkspace
- Frontmost app: Chrome (com.google.Chrome)
- Active window URL: "mail.google.com/mail/u/0/#inbox?compose=new"
- Detection: `.email` with 0.95 confidence
- Method: `.urlAnalysis`

**6b. Text Enhancement Pipeline**:

*Stage 1: Normalize*:
- Input: "hi sarah i wanted to follow up..."
- Output: Same (no issues)

*Stage 2: Remove Fillers*:
- Input: (no fillers in this speech)
- Removed: []

*Stage 3: Punctuate*:
- Add periods, commas, question marks
- Capitalize sentence starts
- Output: "Hi sarah. I wanted to follow up on our meeting yesterday. We discussed the q4 roadmap and I think we should schedule a follow up for next week. Let me know what times work for you. Thanks."

*Stage 4: Format for Email*:
- Capitalize "Sarah" (name detected)
- Format "Q4" (uppercase acronym)
- Add comma after greeting: "Hi Sarah,"
- Add comma after closing: "Thanks,"
- Create paragraphs (2-3 sentences each)
- Output:
  ```
  Hi Sarah,

  I wanted to follow up on our meeting yesterday. We discussed the Q4 roadmap and I think we should schedule a follow-up for next week.

  Let me know what times work for you.

  Thanks,
  ```

*Stage 5: Apply Learning* (if enabled):
- Query learning_patterns for document_type='email'
- No high-confidence patterns found for this specific text
- Patterns applied: 0

*Stage 6: Cloud Enhancement* (SKIPPED - user has not enabled cloud):
- usedCloudAPI: false

**Final EnhancedText**:
- enhancedText: (formatted output above)
- appliedRules: ["Normalize", "Punctuate", "FormatEmail"]
- removedFillers: []
- addedPunctuation: 5 (periods, commas)
- formattingChanges: ["Capitalized names", "Added paragraphs", "Formatted greeting/closing"]
- usedCloudAPI: false
- learningPatternsApplied: 0
- confidence: 0.92

**Processing overlay updates**:
- Status: "Enhancing..." → "Pasting..." (after 0.5s)

---

#### 7. Paste Phase

**Background Processing** (<0.5 seconds):

**7a. Copy to Clipboard**:
- Enhanced text copied to NSPasteboard

**7b. Simulate Paste**:
- PasteService creates CGEvent for Cmd+V
- CGEvent posted to active application (Chrome)
- Gmail receives paste event
- Text inserted at cursor position

**7c. Visual Feedback**:
- Menu bar icon changes to green (🟢) briefly (1s)
- Audio cue: success chime
- Overlay shows "Complete!" then fades out (1s)
- Icon returns to white (ready)

**Expected Result in Gmail**:
Email body field now contains:
```
Hi Sarah,

I wanted to follow up on our meeting yesterday. We discussed the Q4 roadmap and I think we should schedule a follow-up for next week.

Let me know what times work for you.

Thanks,
```

**Expected Performance**:
- Paste operation completes in <500ms (PR-003)

**Expected State**:
```swift
AppState.currentStatus == .pasting → .ready
ClipboardMonitor.startMonitoring(for: 10.0)  // Start 10s learning window
EnhancedText saved for learning observation
```

**Validation**:
```swift
func testPasteCompletesWithin500ms() async throws {
    // Given
    let service = PasteService()
    let text = "Test text"

    // When
    let startTime = Date()
    try await service.paste(text: text)
    let elapsed = Date().timeIntervalSince(startTime)

    // Then
    XCTAssertLessThan(elapsed, 0.5, "Paste must complete in <500ms (PR-003)")

    // Verify clipboard
    let clipboardText = NSPasteboard.general.string(forType: .string)
    XCTAssertEqual(clipboardText, text)
}
```

---

#### 8. Learning Phase (Background, 10 seconds)

**User Behavior** (scenario: user makes small edit):
- User reads pasted text in Gmail
- User edits: Changes "Thanks," to "Best regards,"
- User continues working on email (adds recipient, subject, etc.)

**Background Processing**:

**8a. Clipboard Monitoring**:
- ClipboardMonitor observes NSPasteboard changes
- Detects change at T+3 seconds after paste
- Captures new clipboard content: (full email text with edit)

**8b. Edit Detection**:
- Compare original EnhancedText with clipboard content
- Calculate edit distance: 15 characters changed
- Significant edit: Yes (>10% of closing)

**8c. Pattern Storage**:
```sql
INSERT INTO learning_patterns (
    id, document_type, original_text, edited_text, edit_distance, frequency, confidence
) VALUES (
    '...', 'email', 'Thanks,', 'Best regards,', 15, 1, 0.1
);
```

**8d. Future Application**:
- After frequency reaches 3-5, pattern will be auto-applied
- Future emails with "Thanks," → "Best regards,"
- Demonstrates QR-004 (learning improves over time)

**Validation**:
```swift
func testLearningSystemCapturesEdits() async throws {
    // Given
    let service = LearningService()
    let original = "Thanks,"
    let edited = "Best regards,"

    // When
    await service.observe(
        originalText: original,
        documentType: .email,
        timeoutSeconds: 10
    )

    // Simulate user edit
    NSPasteboard.general.setString(edited, forType: .string)
    try await Task.sleep(nanoseconds: 1_000_000_000)

    // Then
    let patterns = try await service.findSimilarPatterns(text: original, documentType: .email)
    XCTAssertEqual(patterns.count, 1)
    XCTAssertEqual(patterns.first?.editedText, edited)
    XCTAssertEqual(patterns.first?.frequency, 1)
}
```

---

## End-to-End Test

**Full integration test** validating entire flow:

```swift
class BetterVoiceEndToEndTests: XCTestCase {
    func testCompleteEmailTranscriptionWorkflow() async throws {
        // GIVEN: App is running, Gmail is open
        let app = XCUIApplication()
        app.launch()
        try await Task.sleep(nanoseconds: 2_000_000_000)  // Wait for model load

        let chrome = XCUIApplication(bundleIdentifier: "com.google.Chrome")
        chrome.activate()
        // Navigate to Gmail compose (simulated or real)

        // WHEN: User records speech
        let startTime = Date()
        app.pressHotkey(.rightOption)
        try await Task.sleep(nanoseconds: 15_000_000_000)  // Speak for 15s
        app.releaseHotkey(.rightOption)

        // Wait for processing
        let processingComplete = app.statusItem.icon.waitFor(.ready, timeout: 10.0)
        let totalTime = Date().timeIntervalSince(startTime)

        // THEN: All requirements met
        XCTAssertTrue(processingComplete, "Processing should complete")
        XCTAssertLessThan(totalTime, 20.0, "Total flow <20s for 15s audio")

        // Verify paste occurred
        let clipboardText = NSPasteboard.general.string(forType: .string)
        XCTAssertNotNil(clipboardText)
        XCTAssertTrue(clipboardText!.contains("Hi Sarah"))
        XCTAssertTrue(clipboardText!.contains("Thanks,") || clipboardText!.contains("Best regards,"))

        // Verify formatting
        XCTAssertTrue(clipboardText!.contains("\n\n"))  // Paragraphs
        XCTAssertFalse(clipboardText!.contains("um"))  // No fillers
        XCTAssertFalse(clipboardText!.contains("uh"))
    }
}
```

---

## Success Criteria

### Performance (from spec):
- ✅ Hotkey response < 100ms (PR-001)
- ✅ Transcription < 3s for 15s audio with base model (PR-002)
- ✅ Paste < 500ms (PR-003)
- ✅ Total flow < 20s for 15s recording
- ✅ App launch < 2s (PR-004)
- ✅ UI responsive (16ms frame time) throughout (PR-008)

### Quality:
- ✅ Document type detection correct (email detected from Gmail)
- ✅ Filler words removed (if present)
- ✅ Proper punctuation and capitalization
- ✅ Email-specific formatting (greeting, paragraphs, closing)
- ✅ Text pasted into correct application field

### User Experience:
- ✅ Clear visual feedback at each stage (menu bar icons, overlay)
- ✅ Audio cues for start/stop/complete
- ✅ Estimated time displayed
- ✅ No user intervention required after hotkey press
- ✅ Learning system silently captures edits for future improvement

---

## Troubleshooting

**Issue**: No audio detected
- **Check**: Microphone permission granted
- **Check**: Correct input device selected in settings
- **Check**: Mic not muted in system

**Issue**: Transcription fails
- **Check**: Whisper model downloaded
- **Check**: Sufficient disk space (5GB)
- **Check**: Sufficient memory (8GB+)

**Issue**: Text not pasted
- **Check**: Accessibility permission granted
- **Check**: Text field was focused when transcription completed
- **Check**: Application supports paste operations

**Issue**: Wrong document type detected
- **Check**: Application in focus when transcription completes
- **Check**: For browser apps, URL must be accessible (not blocked by privacy settings)

---

This quickstart validates the primary user scenario end-to-end and serves as both user documentation and integration test specification.
