//
//  AudioRecordingTests.swift
//  BetterVoiceTests
//
//  Unit tests for AudioRecording model
//  Tests MUST FAIL until implementation (TDD Red phase)
//

import XCTest
@testable import BetterVoice

final class AudioRecordingTests: XCTestCase {

    // MARK: - Codable Conformance

    func testAudioRecordingIsEncodable() throws {
        // Given
        let recording = AudioRecording(
            id: UUID(),
            timestamp: Date(),
            duration: 15.5,
            sampleRate: 16000,
            channels: 1,
            format: "PCM16",
            filePath: URL(fileURLWithPath: "/tmp/test.wav"),
            fileSize: 123456,
            deviceName: "Built-in Microphone",
            deviceUID: "AppleHDAEngineInput:1B,0,1,0:1"
        )

        // When
        let encoded = try JSONEncoder().encode(recording)

        // Then
        XCTAssertGreaterThan(encoded.count, 0, "Should encode to JSON")
    }

    func testAudioRecordingIsDecodable() throws {
        // Given
        let recording = AudioRecording(
            id: UUID(),
            timestamp: Date(),
            duration: 10.0,
            sampleRate: 16000,
            channels: 1,
            format: "PCM16",
            filePath: nil,
            fileSize: 320000,
            deviceName: "Test Mic",
            deviceUID: "test-uid"
        )

        let encoded = try JSONEncoder().encode(recording)

        // When
        let decoded = try JSONDecoder().decode(AudioRecording.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.id, recording.id)
        XCTAssertEqual(decoded.duration, recording.duration)
        XCTAssertEqual(decoded.sampleRate, recording.sampleRate)
        XCTAssertEqual(decoded.format, recording.format)
    }

    // MARK: - Validation Rules

    func testValidAudioRecording() {
        // Given
        let recording = AudioRecording(
            id: UUID(),
            timestamp: Date(),
            duration: 30.0,
            sampleRate: 16000,
            channels: 1,
            format: "PCM16",
            filePath: URL(fileURLWithPath: "/tmp/audio.wav"),
            fileSize: 960000,
            deviceName: "Mic",
            deviceUID: "uid-123"
        )

        // Then
        XCTAssertTrue(recording.isValid, "Valid recording should pass all validation")
    }

    func testInvalidDurationTooLong() {
        // Given: Duration > 7200s (2 hours max per FR-029)
        let recording = AudioRecording(
            id: UUID(),
            timestamp: Date(),
            duration: 7201.0, // 1 second over limit
            sampleRate: 16000,
            channels: 1,
            format: "PCM16",
            filePath: nil,
            fileSize: 0,
            deviceName: "Mic",
            deviceUID: "uid"
        )

        // Then
        XCTAssertFalse(recording.isValid, "Duration > 7200s should be invalid")
    }

    func testInvalidDurationZero() {
        // Given
        let recording = AudioRecording(
            id: UUID(),
            timestamp: Date(),
            duration: 0.0,
            sampleRate: 16000,
            channels: 1,
            format: "PCM16",
            filePath: nil,
            fileSize: 0,
            deviceName: "Mic",
            deviceUID: "uid"
        )

        // Then
        XCTAssertFalse(recording.isValid, "Duration = 0 should be invalid")
    }

    func testInvalidSampleRate() {
        // Given: Sample rate != 16000 (Whisper requirement)
        let recording = AudioRecording(
            id: UUID(),
            timestamp: Date(),
            duration: 10.0,
            sampleRate: 44100, // Wrong sample rate
            channels: 1,
            format: "PCM16",
            filePath: nil,
            fileSize: 0,
            deviceName: "Mic",
            deviceUID: "uid"
        )

        // Then
        XCTAssertFalse(recording.isValid, "Sample rate must be 16000")
    }

    func testInvalidChannelCount() {
        // Given: Channels != 1 (mono required)
        let recording = AudioRecording(
            id: UUID(),
            timestamp: Date(),
            duration: 10.0,
            sampleRate: 16000,
            channels: 2, // Stereo not allowed
            format: "PCM16",
            filePath: nil,
            fileSize: 0,
            deviceName: "Mic",
            deviceUID: "uid"
        )

        // Then
        XCTAssertFalse(recording.isValid, "Channels must be 1 (mono)")
    }

    func testInvalidFormat() {
        // Given: Format != "PCM16"
        let recording = AudioRecording(
            id: UUID(),
            timestamp: Date(),
            duration: 10.0,
            sampleRate: 16000,
            channels: 1,
            format: "MP3", // Wrong format
            filePath: nil,
            fileSize: 0,
            deviceName: "Mic",
            deviceUID: "uid"
        )

        // Then
        XCTAssertFalse(recording.isValid, "Format must be PCM16")
    }

    // MARK: - File Path Lifecycle

    func testFilePathExistsDuringTranscription() {
        // Given
        let tempURL = URL(fileURLWithPath: "/tmp/audio-\(UUID()).wav")
        let recording = AudioRecording(
            id: UUID(),
            timestamp: Date(),
            duration: 10.0,
            sampleRate: 16000,
            channels: 1,
            format: "PCM16",
            filePath: tempURL,
            fileSize: 320000,
            deviceName: "Mic",
            deviceUID: "uid"
        )

        // Then
        XCTAssertNotNil(recording.filePath, "File path should exist during transcription")
    }

    func testFilePathNilAfterCleanup() {
        // Given: Recording after FR-016 cleanup
        var recording = AudioRecording(
            id: UUID(),
            timestamp: Date(),
            duration: 10.0,
            sampleRate: 16000,
            channels: 1,
            format: "PCM16",
            filePath: URL(fileURLWithPath: "/tmp/audio.wav"),
            fileSize: 320000,
            deviceName: "Mic",
            deviceUID: "uid"
        )

        // When: Cleanup (simulated)
        recording.filePath = nil

        // Then
        XCTAssertNil(recording.filePath, "File path should be nil after cleanup per FR-016")
    }

    // MARK: - Identifiable Conformance

    func testAudioRecordingIsIdentifiable() {
        // Given
        let id1 = UUID()
        let id2 = UUID()

        let recording1 = AudioRecording(
            id: id1,
            timestamp: Date(),
            duration: 5.0,
            sampleRate: 16000,
            channels: 1,
            format: "PCM16",
            filePath: nil,
            fileSize: 0,
            deviceName: "Mic",
            deviceUID: "uid"
        )

        let recording2 = AudioRecording(
            id: id2,
            timestamp: Date(),
            duration: 5.0,
            sampleRate: 16000,
            channels: 1,
            format: "PCM16",
            filePath: nil,
            fileSize: 0,
            deviceName: "Mic",
            deviceUID: "uid"
        )

        // Then
        XCTAssertEqual(recording1.id, id1)
        XCTAssertEqual(recording2.id, id2)
        XCTAssertNotEqual(recording1.id, recording2.id)
    }

    // MARK: - Computed Properties

    func testExpectedFileSizeCalculation() {
        // Given: 10 seconds at 16kHz mono PCM16
        // Expected: 16000 samples/sec * 2 bytes/sample * 10 sec = 320000 bytes
        let recording = AudioRecording(
            id: UUID(),
            timestamp: Date(),
            duration: 10.0,
            sampleRate: 16000,
            channels: 1,
            format: "PCM16",
            filePath: nil,
            fileSize: 320000,
            deviceName: "Mic",
            deviceUID: "uid"
        )

        let expectedSize = Int64(recording.duration * Double(recording.sampleRate) * 2.0) // 2 bytes per sample

        // Then
        XCTAssertEqual(recording.fileSize, expectedSize, "File size should match PCM16 calculation")
    }
}
