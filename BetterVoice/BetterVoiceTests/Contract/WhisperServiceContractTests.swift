//
//  WhisperServiceContractTests.swift
//  BetterVoiceTests
//
//  Contract tests for WhisperService
//  Tests MUST FAIL until implementation (TDD Red phase)
//

import XCTest
import Combine
@testable import BetterVoice

final class WhisperServiceContractTests: XCTestCase {
    var sut: WhisperService!

    override func setUp() {
        super.setUp()
        sut = WhisperService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Contract: loadModel succeeds for valid model

    func testLoadModelSucceedsForValidModel() async throws {
        // Given
        let baseModel = WhisperModel(
            id: UUID(),
            size: .base,
            fileName: "ggml-base.bin",
            fileSize: 142_356_992,
            storageURL: URL(fileURLWithPath: "/tmp/ggml-base.bin"),
            isDownloaded: true,
            downloadedDate: Date(),
            lastUsed: nil,
            checksumSHA256: "test-checksum",
            modelVersion: "1.0"
        )

        // When
        try await sut.loadModel(baseModel)

        // Then
        XCTAssertTrue(sut.isModelLoaded, "Model should be loaded after loadModel succeeds")
        XCTAssertEqual(sut.currentModel?.size, .base, "Loaded model should match requested model")
    }

    // MARK: - Contract: transcribe returns text for valid audio

    func testTranscribeReturnsTextForValidAudio() async throws {
        // Given
        let baseModel = WhisperModel(
            id: UUID(),
            size: .tiny, // Use tiny for faster tests
            fileName: "ggml-tiny.bin",
            fileSize: 75_497_472,
            storageURL: URL(fileURLWithPath: "/tmp/ggml-tiny.bin"),
            isDownloaded: true,
            downloadedDate: Date(),
            lastUsed: nil,
            checksumSHA256: "test-checksum",
            modelVersion: "1.0"
        )
        try await sut.loadModel(baseModel)

        // Create test PCM16 audio data (silence, 1 second at 16kHz)
        let sampleCount = 16000
        let audioData = Data(count: sampleCount * 2) // 2 bytes per sample (PCM16)

        // When
        let result = try await sut.transcribe(audioData: audioData)

        // Then
        XCTAssertFalse(result.text.isEmpty, "Transcription should return non-empty text")
        XCTAssertNotNil(result.detectedLanguage, "Should detect language")
        XCTAssertGreaterThan(result.languageConfidence, 0.0, "Should have language confidence")
        XCTAssertLessThanOrEqual(result.languageConfidence, 1.0, "Confidence should be 0.0-1.0")
    }

    // MARK: - PR-002: Transcription <3s for 30s audio with base model

    func testTranscriptionMeetsPerformanceRequirement() async throws {
        // Given
        let baseModel = WhisperModel(
            id: UUID(),
            size: .base,
            fileName: "ggml-base.bin",
            fileSize: 142_356_992,
            storageURL: URL(fileURLWithPath: "/tmp/ggml-base.bin"),
            isDownloaded: true,
            downloadedDate: Date(),
            lastUsed: nil,
            checksumSHA256: "test-checksum",
            modelVersion: "1.0"
        )
        try await sut.loadModel(baseModel)

        // Create 30 seconds of test audio (PCM16, 16kHz, mono)
        let sampleCount = 16000 * 30
        let audioData = Data(count: sampleCount * 2)

        // When
        let startTime = Date()
        let result = try await sut.transcribe(audioData: audioData)
        let elapsed = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(elapsed, 3.0, "Transcription must complete in <3s for 30s audio (PR-002)")
        XCTAssertFalse(result.text.isEmpty, "Should return transcription")
    }

    // MARK: - Error Cases

    func testTranscribeThrowsErrorWhenModelNotLoaded() async {
        // Given
        let audioData = Data(count: 32000) // 1 second of PCM16

        // When/Then
        do {
            _ = try await sut.transcribe(audioData: audioData)
            XCTFail("Should throw error when model not loaded")
        } catch {
            XCTAssertTrue(error is WhisperServiceError, "Should throw WhisperServiceError")
        }
    }

    func testTranscribeThrowsErrorForInvalidAudioData() async throws {
        // Given
        let baseModel = WhisperModel(
            id: UUID(),
            size: .tiny,
            fileName: "ggml-tiny.bin",
            fileSize: 75_497_472,
            storageURL: URL(fileURLWithPath: "/tmp/ggml-tiny.bin"),
            isDownloaded: true,
            downloadedDate: Date(),
            lastUsed: nil,
            checksumSHA256: "test-checksum",
            modelVersion: "1.0"
        )
        try await sut.loadModel(baseModel)

        let invalidAudioData = Data([0xFF, 0xFF, 0xFF]) // Too small, invalid

        // When/Then
        do {
            _ = try await sut.transcribe(audioData: invalidAudioData)
            XCTFail("Should throw error for invalid audio")
        } catch {
            XCTAssertTrue(error is WhisperServiceError, "Should throw WhisperServiceError")
        }
    }

    func testLoadModelThrowsErrorForMissingFile() async {
        // Given
        let missingModel = WhisperModel(
            id: UUID(),
            size: .base,
            fileName: "ggml-base.bin",
            storageURL: URL(fileURLWithPath: "/nonexistent/path/ggml-base.bin"),
            isDownloaded: false,
            downloadedDate: nil,
            lastUsed: nil,
            checksumSHA256: "test-checksum",
            modelVersion: "1.0"
        )

        // When/Then
        do {
            try await sut.loadModel(missingModel)
            XCTFail("Should throw error for missing model file")
        } catch {
            XCTAssertTrue(error is WhisperServiceError, "Should throw WhisperServiceError")
        }
    }

    func testCancelStopsTranscription() async throws {
        // Given
        let baseModel = WhisperModel(
            id: UUID(),
            size: .base,
            fileName: "ggml-base.bin",
            fileSize: 142_356_992,
            storageURL: URL(fileURLWithPath: "/tmp/ggml-base.bin"),
            isDownloaded: true,
            downloadedDate: Date(),
            lastUsed: nil,
            checksumSHA256: "test-checksum",
            modelVersion: "1.0"
        )
        try await sut.loadModel(baseModel)

        let audioData = Data(count: 16000 * 30 * 2) // 30s of audio

        // When
        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            sut.cancel()
        }

        // Then
        do {
            _ = try await sut.transcribe(audioData: audioData)
            XCTFail("Should throw error when cancelled")
        } catch {
            XCTAssertTrue(error is WhisperServiceError, "Should throw cancellation error")
        }
    }
}

// MARK: - Supporting Types (Contracts)

protocol WhisperServiceProtocol {
    var isModelLoaded: Bool { get }
    var currentModel: WhisperModel? { get }
    var progressPublisher: AnyPublisher<Float, Never> { get }

    func loadModel(_ model: WhisperModel) async throws
    func transcribe(audioData: Data) async throws -> TranscriptionResult
    func cancel()
}

struct TranscriptionResult {
    let text: String
    let detectedLanguage: String?
    let languageConfidence: Float
    let segments: [TranscriptionSegment]
    let processingTime: TimeInterval
}

struct TranscriptionSegment {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

enum WhisperServiceError: Error {
    case modelNotLoaded
    case modelFileNotFound
    case invalidAudioData
    case transcriptionFailed(String)
    case cancelled
}
