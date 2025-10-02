# Phase 1: Data Model Design

**Feature**: BetterVoice Voice Transcription App
**Date**: 2025-09-30

## Entity Definitions

### 1. AudioRecording

**Purpose**: Represents a captured audio session from microphone

**Fields**:
- `id: UUID` - Unique identifier
- `timestamp: Date` - Recording start time
- `duration: TimeInterval` - Recording length in seconds
- `sampleRate: Int` - Audio sample rate (typically 16000 Hz)
- `channels: Int` - Number of audio channels (1 for mono)
- `format: String` - Audio format identifier ("PCM16")
- `filePath: URL?` - Temporary file path (nil after cleanup)
- `fileSize: Int64` - Audio file size in bytes
- `deviceName: String` - Input device display name
- `deviceUID: String` - Input device unique identifier

**Validation Rules**:
- `duration` must be > 0 and ≤ 7200 seconds (2 hours max per FR-029)
- `sampleRate` must be 16000 (Whisper requirement)
- `channels` must be 1 (mono)
- `format` must be "PCM16"
- `filePath` must exist during transcription, nil after FR-016 cleanup

**State Transitions**:
```
created → recording → completed → transcribing → cleanedUp
```

**Swift Model**:
```swift
struct AudioRecording: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval
    let sampleRate: Int
    let channels: Int
    let format: String
    var filePath: URL?
    let fileSize: Int64
    let deviceName: String
    let deviceUID: String

    var isValid: Bool {
        duration > 0 && duration <= 7200 &&
        sampleRate == 16000 &&
        channels == 1 &&
        format == "PCM16"
    }
}
```

---

### 2. TranscriptionJob

**Purpose**: Represents the processing of an audio recording through Whisper

**Fields**:
- `id: UUID` - Unique identifier
- `audioRecordingID: UUID` - Foreign key to AudioRecording
- `modelSize: WhisperModelSize` - Selected model (tiny/base/small/medium/large)
- `detectedLanguage: String?` - ISO language code (e.g., "en", "es")
- `languageConfidence: Float?` - Detection confidence 0.0-1.0
- `status: TranscriptionStatus` - Current processing state
- `startTime: Date?` - When transcription began
- `endTime: Date?` - When transcription completed
- `rawTranscription: String?` - Unformatted output from Whisper
- `error: String?` - Error message if failed

**Enums**:
```swift
enum WhisperModelSize: String, Codable {
    case tiny = "tiny"          // 75 MB
    case base = "base"          // 142 MB
    case small = "small"        // 466 MB
    case medium = "medium"      // 1.5 GB
    case large = "large"        // 2.9 GB
}

enum TranscriptionStatus: String, Codable {
    case queued
    case modelLoading
    case transcribing
    case completed
    case failed
}
```

**Validation Rules**:
- `status` transitions: queued → modelLoading → transcribing → (completed|failed)
- `endTime` must be > `startTime` when completed
- `rawTranscription` required when status == completed
- `error` required when status == failed
- Processing duration must meet PR-002 (<3s for 30s audio with base model)

**Relationships**:
- Many-to-one with AudioRecording

**Swift Model**:
```swift
struct TranscriptionJob: Codable, Identifiable {
    let id: UUID
    let audioRecordingID: UUID
    let modelSize: WhisperModelSize
    var detectedLanguage: String?
    var languageConfidence: Float?
    var status: TranscriptionStatus
    var startTime: Date?
    var endTime: Date?
    var rawTranscription: String?
    var error: String?

    var processingDuration: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }

    var isComplete: Bool {
        status == .completed && rawTranscription != nil
    }
}
```

---

### 3. DocumentTypeContext

**Purpose**: Captures detected application and document type for enhancement decisions

**Fields**:
- `id: UUID` - Unique identifier
- `timestamp: Date` - When detection occurred
- `frontmostAppBundleID: String` - Active app bundle ID (e.g., "com.apple.mail")
- `frontmostAppName: String` - User-facing app name (e.g., "Mail")
- `windowTitle: String?` - Active window title if available
- `url: String?` - For browser apps, the active URL
- `detectedType: DocumentType` - Determined document type
- `detectionMethod: DetectionMethod` - How type was determined
- `confidence: Float` - Detection confidence 0.0-1.0

**Enums**:
```swift
enum DocumentType: String, Codable {
    case email
    case message
    case document
    case searchQuery
    case unknown
}

enum DetectionMethod: String, Codable {
    case bundleIDMapping      // Direct app → type mapping
    case urlAnalysis          // Browser URL pattern matching
    case nlpFallback         // Text content analysis
    case userOverride        // Manual user selection
}
```

**Validation Rules**:
- `confidence` must be 0.0-1.0
- `detectionMethod` determines required fields:
  - `bundleIDMapping`: requires `frontmostAppBundleID`
  - `urlAnalysis`: requires `url`
  - `nlpFallback`: requires text sample (external)
- Target >85% accuracy (QR-002)

**Swift Model**:
```swift
struct DocumentTypeContext: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let frontmostAppBundleID: String
    let frontmostAppName: String
    let windowTitle: String?
    let url: String?
    let detectedType: DocumentType
    let detectionMethod: DetectionMethod
    let confidence: Float

    var isConfident: Bool { confidence >= 0.85 }
}
```

---

### 4. EnhancedText

**Purpose**: Final formatted text output ready for pasting

**Fields**:
- `id: UUID` - Unique identifier
- `transcriptionJobID: UUID` - Foreign key to TranscriptionJob
- `documentTypeContextID: UUID` - Foreign key to DocumentTypeContext
- `timestamp: Date` - When enhancement completed
- `originalText: String` - Raw transcription input
- `enhancedText: String` - Final formatted output
- `appliedRules: [String]` - Names of enhancement rules applied
- `removedFillers: [String]` - Filler words that were removed
- `addedPunctuation: Int` - Count of punctuation marks added
- `formattingChanges: [String]` - Descriptions of formatting applied
- `usedCloudAPI: Bool` - Whether cloud enhancement was used
- `cloudProvider: String?` - Provider name if cloud used
- `learningPatternsApplied: Int` - Count of learned patterns used
- `confidence: Float` - Overall quality confidence 0.0-1.0

**Validation Rules**:
- `enhancedText` must not be empty
- `confidence` must be 0.0-1.0
- If `usedCloudAPI` == true, `cloudProvider` must be set
- `enhancedText` should differ meaningfully from `originalText`

**Relationships**:
- One-to-one with TranscriptionJob
- One-to-one with DocumentTypeContext

**Swift Model**:
```swift
struct EnhancedText: Codable, Identifiable {
    let id: UUID
    let transcriptionJobID: UUID
    let documentTypeContextID: UUID
    let timestamp: Date
    let originalText: String
    let enhancedText: String
    let appliedRules: [String]
    let removedFillers: [String]
    let addedPunctuation: Int
    let formattingChanges: [String]
    let usedCloudAPI: Bool
    let cloudProvider: String?
    let learningPatternsApplied: Int
    let confidence: Float

    var improvementRatio: Float {
        let changes = Float(removedFillers.count + addedPunctuation + formattingChanges.count)
        return changes / Float(max(originalText.count, 1))
    }
}
```

---

### 5. LearningPattern

**Purpose**: Stores user editing patterns for adaptive enhancement

**Database Table** (SQLite via GRDB):
```sql
CREATE TABLE learning_patterns (
    id TEXT PRIMARY KEY,
    document_type TEXT NOT NULL,
    original_text TEXT NOT NULL,
    edited_text TEXT NOT NULL,
    edit_distance INTEGER NOT NULL,
    frequency INTEGER DEFAULT 1,
    first_seen TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    confidence REAL DEFAULT 1.0,
    metadata TEXT  -- JSON for additional context
);

CREATE INDEX idx_learning_doc_type ON learning_patterns(document_type);
CREATE INDEX idx_learning_frequency ON learning_patterns(frequency DESC, last_seen DESC);
CREATE INDEX idx_learning_confidence ON learning_patterns(confidence DESC);
```

**Fields**:
- `id: UUID` - Unique identifier (stored as TEXT)
- `documentType: DocumentType` - Type where pattern was observed
- `originalText: String` - Text before user edit
- `editedText: String` - Text after user edit
- `editDistance: Int` - Levenshtein distance between original and edited
- `frequency: Int` - How many times this pattern observed
- `firstSeen: Date` - First occurrence timestamp
- `lastSeen: Date` - Most recent occurrence timestamp
- `confidence: Float` - Pattern reliability 0.0-1.0
- `metadata: [String: String]?` - Additional context (JSON)

**Validation Rules**:
- `editDistance` must be > 0 (no-op edits not stored)
- `editDistance` must be ≥ 10% of `originalText`.count (meaningful edits only per research.md)
- `frequency` increments on repeated observations
- `confidence` calculated as: min(1.0, frequency / 10.0)
- Patterns with `confidence` < 0.3 auto-pruned after 30 days

**Relationships**:
- Referenced by EnhancedText (count only, not foreign key)

**Swift Model**:
```swift
struct LearningPattern: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: UUID
    let documentType: DocumentType
    let originalText: String
    let editedText: String
    let editDistance: Int
    var frequency: Int
    let firstSeen: Date
    var lastSeen: Date
    var confidence: Float
    var metadata: [String: String]?

    var isTrusted: Bool { confidence >= 0.7 }
    var isSignificantEdit: Bool { editDistance >= (originalText.count / 10) }

    static let databaseTableName = "learning_patterns"
}
```

---

### 6. WhisperModel

**Purpose**: Represents available or installed Whisper model files

**Fields**:
- `id: UUID` - Unique identifier
- `size: WhisperModelSize` - Model size enum
- `fileName: String` - File name (e.g., "ggml-base.bin")
- `fileSize: Int64` - Expected file size in bytes
- `storageURL: URL` - File path in Application Support
- `isDownloaded: Bool` - Whether file exists locally
- `downloadedDate: Date?` - When download completed
- `lastUsed: Date?` - Last time model was loaded
- `checksumSHA256: String` - File integrity checksum
- `modelVersion: String` - Whisper model version (e.g., "1.0")

**Constants**:
```swift
extension WhisperModel {
    static let modelSizes: [WhisperModelSize: (fileName: String, bytes: Int64)] = [
        .tiny: ("ggml-tiny.bin", 75_497_472),
        .base: ("ggml-base.bin", 142_356_992),
        .small: ("ggml-small.bin", 466_043_136),
        .medium: ("ggml-medium.bin", 1_533_341_696),
        .large: ("ggml-large.bin", 2_946_424_832)
    ]
}
```

**Validation Rules**:
- `storageURL` must be within `~/Library/Application Support/BetterVoice/models/` (FR-015)
- If `isDownloaded` == true, file must exist at `storageURL`
- File at `storageURL` must match `checksumSHA256` for integrity
- Auto-download triggered on first use per FR-005

**State Transitions**:
```
notDownloaded → downloading → verifying → ready → (loaded | error)
```

**Swift Model**:
```swift
struct WhisperModel: Codable, Identifiable {
    let id: UUID
    let size: WhisperModelSize
    let fileName: String
    let fileSize: Int64
    let storageURL: URL
    var isDownloaded: Bool
    var downloadedDate: Date?
    var lastUsed: Date?
    let checksumSHA256: String
    let modelVersion: String

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var needsDownload: Bool { !isDownloaded }
}
```

---

### 7. UserPreferences

**Purpose**: Stores user configuration and settings

**Storage**: UserDefaults + Codable

**Fields**:
- `hotkeyKeyCode: UInt32` - Virtual key code for hotkey (default: 61 = Right Option)
- `hotkeyModifiers: UInt32` - Modifier flags (default: 0 for no modifiers)
- `selectedModelSize: WhisperModelSize` - Default Whisper model (default: .base)
- `selectedAudioInputDeviceUID: String?` - Audio input device UID (nil = system default)
- `audioFeedbackEnabled: Bool` - Play audio cues (default: true)
- `visualOverlayEnabled: Bool` - Show recording overlay (default: true)
- `learningSystemEnabled: Bool` - Enable learning from edits (default: true)
- `externalLLMEnabled: Bool` - Enable cloud enhancement (default: false)
- `externalLLMProvider: String?` - Provider name ("Claude" or "OpenAI")
- `logLevel: LogLevel` - Logging verbosity (default: .info)
- `autoDeleteTranscriptions: Bool` - Auto-delete old transcriptions (default: false)
- `autoDeleteAfterDays: Int` - Days to keep transcriptions (default: 30)

**Enum**:
```swift
enum LogLevel: String, Codable {
    case debug, info, warning, error
}
```

**Validation Rules**:
- If `externalLLMEnabled` == true, `externalLLMProvider` must be set
- `autoDeleteAfterDays` must be ≥ 1 if `autoDeleteTranscriptions` == true
- `hotkeyKeyCode` must be valid macOS virtual key code

**Swift Model**:
```swift
struct UserPreferences: Codable {
    var hotkeyKeyCode: UInt32 = 61  // Right Option
    var hotkeyModifiers: UInt32 = 0
    var selectedModelSize: WhisperModelSize = .base
    var selectedAudioInputDeviceUID: String?
    var audioFeedbackEnabled: Bool = true
    var visualOverlayEnabled: Bool = true
    var learningSystemEnabled: Bool = true
    var externalLLMEnabled: Bool = false
    var externalLLMProvider: String?
    var logLevel: LogLevel = .info
    var autoDeleteTranscriptions: Bool = false
    var autoDeleteAfterDays: Int = 30

    static let storageKey = "BetterVoice.UserPreferences"

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.storageKey)
    }

    static func load() -> UserPreferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return UserPreferences()
        }
        return prefs
    }
}
```

---

### 8. ExternalLLMConfig

**Purpose**: Configuration for cloud API enhancement providers

**Fields**:
- `id: UUID` - Unique identifier
- `provider: String` - Provider name ("Claude" or "OpenAI")
- `isEnabled: Bool` - Whether provider is currently active
- `apiKeyKeychainItem: String` - Keychain item name (not the key itself)
- `endpoint: URL` - API endpoint URL
- `model: String` - Model identifier (e.g., "claude-3-sonnet-20240229")
- `systemPrompts: [DocumentType: String]` - Custom prompts per document type
- `timeoutSeconds: TimeInterval` - API call timeout (default: 30)
- `maxRetries: Int` - Retry attempts on failure (default: 2)
- `lastTestDate: Date?` - Last successful connection test
- `lastTestStatus: Bool?` - Whether last test succeeded

**Default System Prompts**:
```swift
extension ExternalLLMConfig {
    static let defaultSystemPrompts: [DocumentType: String] = [
        .email: "Format this transcribed speech as a professional email with proper greeting, paragraphs, and closing. Fix grammar and spelling.",
        .message: "Format this transcribed speech as a casual message. Preserve informal tone but fix grammar. Keep it concise.",
        .document: "Format this transcribed speech as structured document text with proper headings, lists, and paragraphs. Use professional tone.",
        .searchQuery: "Convert this transcribed speech into a concise search query. Extract key terms and remove filler words.",
        .unknown: "Format this transcribed speech with proper punctuation, grammar, and paragraph structure."
    ]
}
```

**Validation Rules**:
- `apiKeyKeychainItem` must reference existing Keychain entry (SR-003)
- `systemPrompts` must have entry for each DocumentType
- `timeoutSeconds` must be 5-120 seconds
- `maxRetries` must be 0-5

**Security**:
- API keys stored in macOS Keychain, never in UserDefaults or files
- Keychain items use `kSecAttrService = "com.bettervoice.apikeys"`
- Access requires app to be running (no external tool access)

**Swift Model**:
```swift
struct ExternalLLMConfig: Codable, Identifiable {
    let id: UUID
    let provider: String
    var isEnabled: Bool
    let apiKeyKeychainItem: String
    let endpoint: URL
    var model: String
    var systemPrompts: [DocumentType: String]
    var timeoutSeconds: TimeInterval = 30
    var maxRetries: Int = 2
    var lastTestDate: Date?
    var lastTestStatus: Bool?

    var isConfigured: Bool {
        isEnabled && (try? KeychainHelper.retrieve(item: apiKeyKeychainItem)) != nil
    }
}
```

---

## Entity Relationships

```
AudioRecording (1) ──< (1) TranscriptionJob
                              │
                              │ (1)
                              ↓
                          EnhancedText (1) ──< (1) DocumentTypeContext
                              │
                              │ (applies many)
                              ↓
                          LearningPattern (many, by document_type)

UserPreferences (singleton)
    ↓
    references WhisperModel (by size)
    references ExternalLLMConfig (by provider)
```

---

## Validation Summary

**Cross-Entity Constraints**:
1. TranscriptionJob.audioRecordingID must reference valid AudioRecording
2. EnhancedText.transcriptionJobID must reference completed TranscriptionJob
3. EnhancedText.documentTypeContextID must reference valid DocumentTypeContext
4. UserPreferences.selectedModelSize must reference downloadable WhisperModel
5. LearningPattern.documentType must match DocumentType enum

**Performance Constraints** (from spec):
- AudioRecording.duration ≤ 7200s (FR-029)
- TranscriptionJob processing ≤ 3s for 30s audio (PR-002)
- EnhancedText generation total pipeline ≤ 5s (PR-003 + buffer)
- LearningPattern queries optimized via indexes

---

## Data Model Completion Checklist

- [x] All 8 key entities from spec defined
- [x] Field types and constraints specified
- [x] Validation rules documented
- [x] Relationships mapped
- [x] State transitions identified
- [x] Swift models drafted
- [x] Database schema for LearningPattern
- [x] Security considerations (Keychain for API keys)
- [x] Performance constraints validated against spec requirements

**Proceed to Contract Generation**
