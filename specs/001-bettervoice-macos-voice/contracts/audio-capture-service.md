# Service Contract: AudioCaptureService

**Purpose**: Captures audio from microphone device while hotkey is held

**Compliance**: FR-001 (capture while hotkey held), FR-002 (stop immediately on release), PR-001 (<100ms start latency)

## Interface

```swift
protocol AudioCaptureServiceProtocol {
    /// Start capturing audio from specified input device
    /// - Parameter deviceUID: Audio input device unique identifier (nil = system default)
    /// - Throws: AudioCaptureError if device unavailable or permissions denied
    /// - Returns: Immediately after capture starts
    /// - Latency Requirement: Must complete within 100ms (PR-001)
    func startCapture(deviceUID: String?) throws

    /// Stop capturing audio and return recorded data
    /// - Returns: PCM16 audio data (16kHz mono)
    /// - Throws: AudioCaptureError if no active capture
    /// - Postcondition: Audio data is in memory, no file created yet
    func stopCapture() throws -> Data

    /// Current audio level for waveform visualization
    /// - Returns: RMS power level in dB (-160.0 to 0.0)
    var currentAudioLevel: Float { get }

    /// Publisher for real-time audio level updates (FR-010)
    var audioLevelPublisher: AnyPublisher<Float, Never> { get }

    /// Whether audio capture is currently active
    var isCapturing: Bool { get }
}
```

## Error Types

```swift
enum AudioCaptureError: LocalizedError {
    case permissionDenied           // Microphone permission not granted
    case deviceNotFound(String)     // Specified device UID not available
    case alreadyCapturing          // startCapture called while already capturing
    case notCapturing              // stopCapture called with no active capture
    case engineStartFailed(Error)  // AVAudioEngine failed to start
    case bufferOverflow            // Audio buffer exceeded capacity

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access denied. Please grant permission in System Settings > Privacy & Security > Microphone."
        case .deviceNotFound(let uid):
            return "Audio input device '\(uid)' not found. Please check your audio settings."
        case .alreadyCapturing:
            return "Audio capture already in progress."
        case .notCapturing:
            return "No active audio capture to stop."
        case .engineStartFailed(let error):
            return "Failed to start audio engine: \(error.localizedDescription)"
        case .bufferOverflow:
            return "Recording too long. Maximum recording length is 2 hours."
        }
    }
}
```

## Input Constraints

**startCapture**:
- `deviceUID` must be valid macOS audio input device UID or nil for default
- Microphone permission must be granted (checked via `AVCaptureDevice.authorizationStatus`)
- Must not be called while `isCapturing == true`

**stopCapture**:
- Must be called only when `isCapturing == true`
- Should be called within 7200 seconds (2 hours) of startCapture to avoid buffer overflow

## Output Guarantees

**startCapture**:
- Completes within 100ms or throws
- Sets `isCapturing = true` on success
- Begins emitting `audioLevelPublisher` updates at 60 Hz
- No audio data is lost from time of call

**stopCapture**:
- Returns Data object containing complete PCM16 audio
- Audio format: 16kHz sample rate, 1 channel (mono), 16-bit signed integer
- Data size = sampleRate × duration × 2 bytes per sample
- Sets `isCapturing = false`
- Stops emitting `audioLevelPublisher` updates
- Audio engine cleaned up (no background processing)

**audioLevelPublisher**:
- Emits Float values in range -160.0 to 0.0 (dB)
- Update frequency: ~60 Hz (for smooth waveform visualization)
- Only emits while `isCapturing == true`

## Performance Requirements

- **Start latency**: < 100ms from `startCapture()` call to first audio sample captured (PR-001)
- **Stop latency**: < 50ms from `stopCapture()` call to returned Data
- **CPU usage**: < 5% while capturing (lightweight monitoring)
- **Memory**: Audio buffer size = duration × 32KB/second (16kHz × 2 bytes)
- **Maximum duration**: 7200 seconds (2 hours) per FR-029

## Side Effects

**startCapture**:
- Activates microphone hardware (LED indicator may illuminate)
- Allocates audio buffer in memory (~32KB per second)
- Registers AVAudioEngine audio tap on input node
- Blocks other apps from exclusive microphone access (standard macOS behavior)

**stopCapture**:
- Deactivates microphone hardware
- Keeps audio buffer in memory until Data is consumed
- Removes audio tap
- Releases microphone for other apps

## Testing Strategy

**Contract Tests** (verify interface compliance):
```swift
class AudioCaptureServiceContractTests: XCTestCase {
    func testStartCaptureCompletesWithin100ms() async throws {
        // Given
        let service = AudioCaptureService()
        let expectation = expectation(description: "Start within 100ms")

        // When
        let start = Date()
        try service.startCapture(deviceUID: nil)
        let elapsed = Date().timeIntervalSince(start)

        // Then
        XCTAssertLessThan(elapsed, 0.1, "Start latency must be < 100ms (PR-001)")
        XCTAssertTrue(service.isCapturing)

        // Cleanup
        _ = try service.stopCapture()
    }

    func testStopCaptureReturnsPCM16Data() throws {
        // Given
        let service = AudioCaptureService()
        try service.startCapture(deviceUID: nil)
        Thread.sleep(forTimeInterval: 1.0)  // Capture 1 second

        // When
        let audioData = try service.stopCapture()

        // Then
        XCTAssertFalse(service.isCapturing)
        XCTAssertGreaterThan(audioData.count, 0)
        // 16kHz * 1 second * 2 bytes ≈ 32KB
        XCTAssertEqual(audioData.count, 16000 * 2, accuracy: 1000)
    }

    func testStartCaptureWhileCapturingThrows() throws {
        // Given
        let service = AudioCaptureService()
        try service.startCapture(deviceUID: nil)

        // When/Then
        XCTAssertThrowsError(try service.startCapture(deviceUID: nil)) { error in
            XCTAssertEqual(error as? AudioCaptureError, .alreadyCapturing)
        }

        // Cleanup
        _ = try service.stopCapture()
    }

    func testStopCaptureWithoutStartThrows() {
        // Given
        let service = AudioCaptureService()

        // When/Then
        XCTAssertThrowsError(try service.stopCapture()) { error in
            XCTAssertEqual(error as? AudioCaptureError, .notCapturing)
        }
    }

    func testAudioLevelPublisherEmitsWhileCapturing() async throws {
        // Given
        let service = AudioCaptureService()
        var receivedLevels: [Float] = []
        let cancellable = service.audioLevelPublisher
            .sink { level in receivedLevels.append(level) }

        // When
        try service.startCapture(deviceUID: nil)
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        _ = try service.stopCapture()

        // Then
        XCTAssertGreaterThan(receivedLevels.count, 3)  // At least 60Hz * 0.1s
        XCTAssertTrue(receivedLevels.allSatisfy { $0 >= -160.0 && $0 <= 0.0 })

        cancellable.cancel()
    }

    func testPermissionDeniedError() {
        // Given
        // Simulate denied permission (requires mocking AVCaptureDevice)
        let service = MockAudioCaptureService(simulatePermissionDenied: true)

        // When/Then
        XCTAssertThrowsError(try service.startCapture(deviceUID: nil)) { error in
            guard case AudioCaptureError.permissionDenied = error else {
                XCTFail("Expected permissionDenied error")
                return
            }
        }
    }
}
```

## Integration Points

**Upstream** (called by):
- `HotkeyManager` - triggers startCapture on key press, stopCapture on release

**Downstream** (calls):
- `AVAudioEngine` - audio hardware interface
- `AVCaptureDevice` - permission checking
- `PermissionsManager` - request microphone access if needed

**Data Flow**:
```
HotkeyManager → AudioCaptureService.startCapture()
                        ↓
                  [Audio capture active]
                        ↓
HotkeyManager → AudioCaptureService.stopCapture() → Data (PCM16)
                                                        ↓
                                                  AudioRecording model
                                                        ↓
                                                  WhisperService
```
