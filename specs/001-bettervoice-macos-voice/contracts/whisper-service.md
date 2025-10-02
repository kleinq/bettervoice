# Service Contract: WhisperService

**Purpose**: Transcribes audio data using local whisper.cpp models

**Compliance**: FR-003 (local transcription), FR-004 (5 model sizes), FR-005 (auto-download), FR-034 (language detection), PR-002 (<3s for 30s audio with base model)

## Interface

```swift
protocol WhisperServiceProtocol {
    /// Load Whisper model into memory
    /// - Parameter model: WhisperModel to load
    /// - Throws: WhisperError if model file missing or corrupted
    /// - Note: Should be called once on app launch for selected default model
    func loadModel(_ model: WhisperModel) async throws

    /// Transcribe PCM16 audio data
    /// - Parameter audioData: PCM16 format, 16kHz mono audio
    /// - Returns: Transcription result with detected language
    /// - Throws: WhisperError if transcription fails
    /// - Performance: Must complete within 3s for 30s audio with base model (PR-002)
    func transcribe(audioData: Data) async throws -> TranscriptionResult

    /// Cancel active transcription
    func cancel()

    /// Currently loaded model
    var loadedModel: WhisperModel? { get }

    /// Whether transcription is in progress
    var isTranscribing: Bool { get }

    /// Progress publisher (0.0 to 1.0) for long transcriptions
    var progressPublisher: AnyPublisher<Float, Never> { get }
}

struct TranscriptionResult {
    let text: String
    let detectedLanguage: String  // ISO 639-1 code
    let languageConfidence: Float  // 0.0 to 1.0
    let processingDuration: TimeInterval
}
```

## Error Types

```swift
enum WhisperError: LocalizedError {
    case modelNotLoaded
    case modelFileNotFound(String)
    case modelCorrupted(String)
    case invalidAudioFormat
    case transcriptionFailed(String)
    case cancelled
    case memoryExhausted

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No Whisper model loaded. Please select a model in settings."
        case .modelFileNotFound(let path):
            return "Model file not found at \(path). Please download the model."
        case .modelCorrupted(let path):
            return "Model file at \(path) is corrupted. Please re-download."
        case .invalidAudioFormat:
            return "Audio must be PCM16 format, 16kHz mono."
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .cancelled:
            return "Transcription was cancelled."
        case .memoryExhausted:
            return "Insufficient memory for transcription. Try a smaller model or shorter audio."
        }
    }
}
```

## Input Constraints

**loadModel**:
- Model file must exist at `model.storageURL`
- Model file must match `model.checksumSHA256`
- Sufficient memory must be available (model sizes: 75MB to 2.9GB)
- Cannot load while `isTranscribing == true`

**transcribe**:
- `audioData` must be valid PCM16 format
- Sample rate must be 16kHz (checked via data size validation)
- Audio must be mono (1 channel)
- `loadedModel` must not be nil
- Audio duration must be ≤ 7200 seconds (2 hours per FR-029)

## Output Guarantees

**loadModel**:
- Model loaded into memory on success
- Sets `loadedModel` property
- Subsequent transcription calls use this model
- Previous model (if any) is unloaded

**transcribe**:
- Returns `TranscriptionResult` with non-empty `text` on success
- `detectedLanguage` is valid ISO 639-1 code (e.g., "en", "es", "fr")
- `languageConfidence` is 0.0 to 1.0 (typically >0.9 for clear speech)
- `processingDuration` includes only transcription time (not model loading)
- Sets `isTranscribing = false` after completion
- Emits progress updates via `progressPublisher` for audio >60s

**Performance**: For base model with 30-second audio:
- Processing time < 3 seconds (PR-002)
- Memory usage < 500MB (FR-028 hard limit)
- CPU usage spikes to 100% briefly, then averages <50% (FR-027)

## Side Effects

**loadModel**:
- Allocates model size in memory (75MB to 2.9GB depending on model)
- Unloads previous model if loaded
- May trigger garbage collection
- File I/O to read model from disk

**transcribe**:
- High CPU usage during processing (50-100%)
- Memory allocation for audio buffers and intermediate results
- CoreML/Metal acceleration may be used (transparent to caller)
- Emits progress updates to `progressPublisher`

## Testing Strategy

**Contract Tests**:
```swift
class WhisperServiceContractTests: XCTestCase {
    func testLoadModelSucceeds() async throws {
        // Given
        let service = WhisperService()
        let model = WhisperModel.mockTinyModel()  // Pre-downloaded test model

        // When
        try await service.loadModel(model)

        // Then
        XCTAssertEqual(service.loadedModel?.size, .tiny)
    }

    func testTranscribeReturnsTextForValidAudio() async throws {
        // Given
        let service = WhisperService()
        try await service.loadModel(WhisperModel.mockTinyModel())
        let audioData = AudioTestData.pcm16Audio(duration: 5.0, content: "Hello world")

        // When
        let result = try await service.transcribe(audioData: audioData)

        // Then
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertEqual(result.detectedLanguage, "en")
        XCTAssertGreaterThan(result.languageConfidence, 0.8)
    }

    func testTranscribeMeetsPerformanceRequirement() async throws {
        // Given
        let service = WhisperService()
        try await service.loadModel(WhisperModel.mockBaseModel())
        let audioData = AudioTestData.pcm16Audio(duration: 30.0)

        // When
        let start = Date()
        let result = try await service.transcribe(audioData: audioData)
        let elapsed = Date().timeIntervalSince(start)

        // Then
        XCTAssertLessThan(elapsed, 3.0, "Must complete within 3s for 30s audio (PR-002)")
    }

    func testTranscribeWithoutLoadedModelThrows() async {
        // Given
        let service = WhisperService()
        let audioData = AudioTestData.pcm16Audio(duration: 1.0)

        // When/Then
        await XCTAssertThrowsError(try await service.transcribe(audioData: audioData)) { error in
            XCTAssertEqual(error as? WhisperError, .modelNotLoaded)
        }
    }

    func testCancelStopsTranscription() async throws {
        // Given
        let service = WhisperService()
        try await service.loadModel(WhisperModel.mockBaseModel())
        let audioData = AudioTestData.pcm16Audio(duration: 300.0)  // 5 minutes

        // When
        Task {
            try await Task.sleep(nanoseconds: 500_000_000)  // Wait 0.5s
            service.cancel()
        }

        // Then
        await XCTAssertThrowsError(try await service.transcribe(audioData: audioData)) { error in
            XCTAssertEqual(error as? WhisperError, .cancelled)
        }
    }

    func testInvalidAudioFormatThrows() async throws {
        // Given
        let service = WhisperService()
        try await service.loadModel(WhisperModel.mockTinyModel())
        let invalidData = Data(repeating: 0xFF, count: 1000)  // Not PCM16

        // When/Then
        await XCTAssertThrowsError(try await service.transcribe(audioData: invalidData)) { error in
            XCTAssertEqual(error as? WhisperError, .invalidAudioFormat)
        }
    }

    func testProgressPublisherEmitsForLongAudio() async throws {
        // Given
        let service = WhisperService()
        try await service.loadModel(WhisperModel.mockBaseModel())
        let audioData = AudioTestData.pcm16Audio(duration: 120.0)  // 2 minutes
        var progressValues: [Float] = []
        let cancellable = service.progressPublisher
            .sink { progress in progressValues.append(progress) }

        // When
        _ = try await service.transcribe(audioData: audioData)

        // Then
        XCTAssertGreaterThan(progressValues.count, 2)
        XCTAssertTrue(progressValues.first! < progressValues.last!)
        XCTAssertLessThanOrEqual(progressValues.last!, 1.0)

        cancellable.cancel()
    }
}
```

## Integration Points

**Upstream**:
- `TranscriptionQueue` - manages transcription job queue
- `AppState` - loads default model on app launch

**Downstream**:
- `whisper.cpp` C++ library via bridging header
- `ModelDownloadService` - ensures model file exists before loading

**Data Flow**:
```
AudioCaptureService → Data (PCM16)
                         ↓
                   WhisperService.transcribe()
                         ↓
                   TranscriptionResult
                         ↓
                   TextEnhancementService
```

## Notes

- Whisper.cpp performs best on Apple Silicon via CoreML/Metal acceleration
- Model loading is expensive (1-3 seconds), should be done once at app start
- For recordings >60s, progress updates emitted every ~5 seconds
- Language detection is automatic and highly accurate (>95%)
- Whisper supports 99 languages, but English optimization is best
