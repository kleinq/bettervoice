# Phase 0: Research & Technical Decisions

**Feature**: BetterVoice Voice Transcription App
**Date**: 2025-09-30

## Research Areas

### 1. Whisper.cpp Integration

**Decision**: Use whisper.cpp with Swift C++ interop via bridging header

**Rationale**:
- whisper.cpp is optimized C++ implementation of OpenAI Whisper with proven performance
- Supports all 5 model sizes (tiny through large) required by spec
- Native C++ integration provides best performance on Apple Silicon
- Active maintenance and broad community support
- CoreML bindings available for additional optimization

**Alternatives Considered**:
- **Python Whisper via subprocess**: Rejected due to slow IPC, higher memory overhead, Python runtime dependency
- **Transformed ONNX models**: Rejected due to conversion complexity, potential accuracy loss
- **Cloud-only transcription**: Violates constitutional Local-First Processing principle

**Implementation Approach**:
- Add whisper.cpp as git submodule
- Create Swift wrapper class `WhisperService` with C++ bridging
- Use dispatch queues for async transcription to avoid blocking main thread
- Implement model lazy-loading to minimize memory footprint
- Use Metal acceleration via CoreML when available

**Key APIs**:
```swift
// C++ bridge interface
class WhisperService {
    func loadModel(modelPath: String) throws
    func transcribe(audioData: Data) async throws -> String
    func cancel()
}
```

### 2. Hotkey Handling

**Decision**: Use Carbon Events API with fallback to CGEvent for global hotkey monitoring

**Rationale**:
- Carbon `RegisterEventHotKey` provides reliable global hotkey registration
- Captures key events even when app is not frontmost
- Low latency (<100ms required by PR-001)
- Supports modifier keys (Option, Command, Control, Shift)
- Well-documented macOS pattern for menu bar apps

**Alternatives Considered**:
- **NSEvent addGlobalMonitorForEvents**: Rejected - requires Accessibility permission and higher overhead
- **HotKey library (Swift Package)**: Considered but adds unnecessary dependency
- **Custom CGEvent tap**: More complex, similar capability to Carbon

**Implementation Approach**:
- Request Accessibility permission at first launch
- Register hotkey via `RegisterEventHotKey` with user-configurable key code
- Use `EventHotKeyRef` for press/release detection
- Implement state machine: idle → recording → released
- Measure and log latency to verify <100ms requirement

**Key APIs**:
```swift
class HotkeyManager {
    func register(keyCode: UInt32, modifiers: UInt32) throws
    func unregister()
    var onKeyPress: (() -> Void)?
    var onKeyRelease: (() -> Void)?
}
```

### 3. Document Type Detection

**Decision**: Multi-strategy detection: NSWorkspace.shared.frontmostApplication → bundle ID mapping → NLP fallback

**Rationale**:
- `NSWorkspace.shared.frontmostApplication` provides active app bundle ID reliably
- Bundle ID (e.g., `com.google.Chrome`) maps to known apps (Gmail, Slack, etc.)
- URL detection via AXUIElement for browser-based apps (Gmail vs generic Chrome)
- NLP fallback using lightweight text pattern matching when app detection fails
- >85% accuracy achievable with bundle ID + URL combination

**Alternatives Considered**:
- **Accessibility API text field inspection**: Too invasive, performance concerns
- **ML model for document classification**: Overkill, adds latency and complexity
- **User manual selection**: Poor UX, breaks automatic workflow

**Implementation Approach**:
```swift
enum DocumentType {
    case email, message, document, searchQuery, unknown
}

class DocumentTypeDetector {
    // Primary: Bundle ID mapping
    func detect(bundleID: String, url: String?) -> DocumentType

    // Fallback: NLP pattern matching
    func detectFromText(sample: String) -> DocumentType

    // Maps known apps to types
    private let appTypeMap: [String: DocumentType] = [
        "com.apple.mail": .email,
        "com.google.Chrome": .detectFromURL,  // needs URL analysis
        "com.tinyspeck.slackmacgap": .message,
        // ... more mappings
    ]
}
```

**Known Mappings**:
- Email: Mail.app, Outlook, Gmail (chrome+URL), Spark
- Message: Messages.app, Slack, Discord, Telegram, WhatsApp
- Document: TextEdit, Pages, Word, Google Docs (browser), Notion, Bear, Obsidian
- Search: Safari/Chrome/Firefox with search engine URLs

### 4. Text Enhancement Architecture

**Decision**: Pipeline architecture with per-document-type rule chains

**Rationale**:
- Modular design allows independent testing of each enhancement step
- Easy to add/remove enhancement rules per document type
- Supports learning system integration (learned rules as additional pipeline stage)
- Clear separation between filler word removal, punctuation, and formatting

**Pipeline Stages**:
1. **Normalize**: Trim whitespace, normalize Unicode
2. **Remove Fillers**: Pattern-based removal of "um", "uh", "like", "you know"
3. **Punctuate**: Sentence detection, capitalize first word, add periods
4. **Format**: Document-type-specific formatting (lists, paragraphs, salutations)
5. **Apply Learning**: User-learned preferences from LearningPattern database
6. **Cloud Enhance** (optional): LLM refinement if enabled

**Implementation**:
```swift
protocol EnhancementRule {
    func apply(text: String, context: DocumentTypeContext) -> String
}

class TextEnhancementService {
    private var rules: [DocumentType: [EnhancementRule]] = [:]

    func enhance(
        text: String,
        documentType: DocumentType,
        applyLearning: Bool,
        useCloud: Bool
    ) async -> EnhancedText
}
```

### 5. Learning System Design

**Decision**: SQLite (via GRDB) for pattern storage, edit-distance-based pattern matching

**Rationale**:
- GRDB provides type-safe Swift database access with Codable support
- Lightweight (<1MB footprint), no external dependencies
- Pattern matching via edit distance identifies similar transcriptions
- Per-document-type learning prevents cross-contamination
- Incremental learning without model training overhead

**Schema**:
```sql
CREATE TABLE learning_patterns (
    id INTEGER PRIMARY KEY,
    document_type TEXT NOT NULL,
    original_text TEXT NOT NULL,
    edited_text TEXT NOT NULL,
    frequency INTEGER DEFAULT 1,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    confidence REAL DEFAULT 1.0
);

CREATE INDEX idx_patterns_doc_type ON learning_patterns(document_type);
CREATE INDEX idx_patterns_frequency ON learning_patterns(frequency DESC);
```

**Learning Strategy**:
- Monitor clipboard for 10 seconds after paste
- Calculate edit distance between original and edited text
- Store meaningful edits (>10% different, not just typos)
- Increment frequency for repeated patterns
- Apply learned patterns when similarity >80%

**Implementation**:
```swift
class LearningService {
    func observe(
        originalText: String,
        documentType: DocumentType,
        timeoutSeconds: Int = 10
    ) async

    func findSimilarPatterns(
        text: String,
        documentType: DocumentType,
        threshold: Double = 0.8
    ) -> [LearningPattern]

    func applyLearned(
        text: String,
        patterns: [LearningPattern]
    ) -> String
}
```

### 6. Cloud API Integration

**Decision**: Protocol-based abstraction with Claude/OpenAI implementations

**Rationale**:
- Protocol allows easy addition of future LLM providers
- Async/await for non-blocking API calls
- Structured prompts per document type
- Timeout and fallback to local-only enhancement
- Cost tracking per provider

**API Protocol**:
```swift
protocol LLMProvider {
    var name: String { get }
    func enhance(
        text: String,
        documentType: DocumentType,
        systemPrompt: String
    ) async throws -> String
}

class ClaudeAPIClient: LLMProvider {
    // Anthropic Claude API via URLSession
}

class OpenAIAPIClient: LLMProvider {
    // OpenAI Completion API via URLSession
}
```

**System Prompts by Type**:
- **Email**: "Format this transcribed speech as a professional email with proper greeting, paragraphs, and closing."
- **Message**: "Format this transcribed speech as a casual message. Preserve informal tone but fix grammar."
- **Document**: "Format this transcribed speech as structured document text with proper headings, lists, and paragraphs."
- **Search**: "Convert this transcribed speech into a concise search query. Remove filler words."

### 7. Audio Capture & Processing

**Decision**: AVFoundation AVAudioEngine for capture, AVAudioConverter for format conversion

**Rationale**:
- AVAudioEngine provides low-latency audio capture (<100ms)
- Supports configurable sample rates (16kHz required by Whisper)
- Built-in format conversion to PCM16
- Audio tap for real-time waveform visualization
- Automatic handling of device changes

**Audio Format**:
- Sample Rate: 16kHz (Whisper requirement)
- Channels: Mono
- Format: PCM16 (16-bit signed integer)
- Buffer size: 4096 samples (256ms at 16kHz)

**Implementation**:
```swift
class AudioCaptureService {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    func startCapture(device: AVAudioInputDevice) throws
    func stopCapture() -> Data  // Returns PCM16 audio data

    // For waveform visualization
    var audioLevelPublisher: AnyPublisher<Float, Never>
}
```

### 8. Performance Optimization Strategies

**Decisions**:
1. **Threading**: Main queue for UI, background queue for transcription, high-priority queue for hotkey
2. **Memory**: Lazy model loading, streaming audio to temp file for long recordings, immediate cleanup
3. **CPU**: Use CoreML/Metal acceleration when available, limit to 50% sustained via DispatchQoS
4. **Latency**: Pre-warm Whisper model on app launch, use smallest model that meets accuracy threshold

**Monitoring**:
- Instrument `os_signpost` for profiling transcription pipeline
- Log CPU/memory via `os_proc_available_memory()` and `ProcessInfo`
- User-facing latency display in overlay

### 9. Testing Strategy

**Decision**: Three-tier testing with XCTest framework

**Contract Tests** (Interface validation):
- AudioCaptureService produces valid PCM16 data
- WhisperService accepts PCM16 and returns String
- EnhancementService accepts String, returns EnhancedText
- PasteService accepts String and simulates paste

**Integration Tests** (Cross-service workflows):
- End-to-end: Hotkey → Capture → Transcribe → Enhance → Paste
- Learning: Transcribe → Paste → Monitor → Learn → Apply
- Cloud: Transcribe → Enhance locally → Enhance via API → Compare

**Unit Tests** (Isolated logic):
- Model validation (Codable, field constraints)
- Filler word removal algorithms
- Document type detection mappings
- Pattern matching edit distance
- Utility functions (Keychain, Logger)

**Mocking Strategy**:
- Protocol-based services enable easy mocking
- AVAudioEngine mocked with pre-recorded PCM data
- Whisper mocked with deterministic outputs for testing
- Cloud APIs mocked with local responses

### 10. Dependencies

**Swift Packages**:
- `GRDB.swift` (v6.x): SQLite database with type safety
- None others - prefer native frameworks

**System Frameworks**:
- SwiftUI: UI layer
- AppKit: Menu bar, window management
- AVFoundation: Audio capture and processing
- Carbon: Hotkey registration (legacy but necessary)
- Security: Keychain access for API keys
- Foundation: Core utilities

**External**:
- whisper.cpp (git submodule): C++ transcription engine
- Whisper models: Downloaded on-demand to ~/Library/Application Support/BetterVoice/models/

**Build Tools**:
- Xcode 15.3+ (Swift 5.9)
- SwiftLint (code style, optional)
- SwiftFormat (formatting, optional)

---

## Research Completion Checklist

- [x] Whisper.cpp integration approach defined
- [x] Hotkey handling strategy selected
- [x] Document type detection multi-strategy designed
- [x] Text enhancement pipeline architecture specified
- [x] Learning system database schema and matching algorithm defined
- [x] Cloud API abstraction protocol designed
- [x] Audio capture format and APIs selected
- [x] Performance optimization strategies documented
- [x] Testing strategy defined (contract, integration, unit)
- [x] Dependencies and build tools identified

**No NEEDS CLARIFICATION remain** - Proceed to Phase 1
