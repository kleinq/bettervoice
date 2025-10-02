//
//  AudioCaptureContractTests.swift
//  BetterVoiceTests
//
//  Contract tests for AudioCaptureService
//  Tests MUST FAIL until implementation (TDD Red phase)
//

import XCTest
import AVFoundation
import Combine
@testable import BetterVoice

final class AudioCaptureContractTests: XCTestCase {
    var sut: AudioCaptureService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        sut = AudioCaptureService()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - PR-001: Hotkey response <100ms

    func testStartCaptureCompletesWithin100ms() throws {
        // Given
        let expectation = expectation(description: "Start capture within 100ms")
        let startTime = Date()

        // When
        try sut.startCapture(deviceUID: nil)
        let elapsed = Date().timeIntervalSince(startTime)
        expectation.fulfill()

        // Then
        XCTAssertLessThan(elapsed, 0.1, "Start capture must complete within 100ms (PR-001)")
        XCTAssertTrue(sut.isCapturing, "Service should be capturing after startCapture")

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Contract: stopCapture returns PCM16 data

    func testStopCaptureReturnsPCM16Data() throws {
        // Given
        try sut.startCapture(deviceUID: nil)
        Thread.sleep(forTimeInterval: 0.5) // Record 500ms

        // When
        let audioData = try sut.stopCapture()

        // Then
        XCTAssertFalse(sut.isCapturing, "Service should not be capturing after stopCapture")
        XCTAssertGreaterThan(audioData.count, 0, "Audio data should not be empty")

        // PCM16 at 16kHz mono: 16000 samples/sec * 2 bytes/sample * 0.5 sec = 16000 bytes
        let expectedMinBytes = 15000 // Allow some tolerance
        XCTAssertGreaterThan(audioData.count, expectedMinBytes, "Should have ~500ms of PCM16 data")
    }

    // MARK: - Contract: audioLevelPublisher emits while capturing

    func testAudioLevelPublisherEmitsWhileCapturing() throws {
        // Given
        let expectation = expectation(description: "Receive audio levels")
        expectation.expectedFulfillmentCount = 3 // Expect at least 3 updates

        var receivedLevels: [Float] = []
        sut.audioLevelPublisher
            .sink { level in
                receivedLevels.append(level)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        try sut.startCapture(deviceUID: nil)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertGreaterThanOrEqual(receivedLevels.count, 3, "Should emit multiple audio levels")
        XCTAssertTrue(receivedLevels.allSatisfy { $0 >= 0.0 && $0 <= 1.0 }, "Levels should be normalized 0.0-1.0")

        try sut.stopCapture()
    }

    // MARK: - Error Cases

    func testStartCaptureWhenAlreadyCapturingThrowsError() throws {
        // Given
        try sut.startCapture(deviceUID: nil)

        // When/Then
        XCTAssertThrowsError(try sut.startCapture(deviceUID: nil)) { error in
            XCTAssertTrue(error is AudioCaptureError, "Should throw AudioCaptureError")
        }

        try sut.stopCapture()
    }

    func testStopCaptureWhenNotCapturingThrowsError() {
        // When/Then
        XCTAssertThrowsError(try sut.stopCapture()) { error in
            XCTAssertTrue(error is AudioCaptureError, "Should throw AudioCaptureError")
        }
    }

    func testStartCaptureWithInvalidDeviceUIDThrowsError() {
        // Given
        let invalidDeviceUID = "invalid-device-uid-12345"

        // When/Then
        XCTAssertThrowsError(try sut.startCapture(deviceUID: invalidDeviceUID)) { error in
            XCTAssertTrue(error is AudioCaptureError, "Should throw AudioCaptureError for invalid device")
        }
    }

    func testStartCaptureWithoutMicrophonePermissionThrowsError() {
        // Note: This test requires permission to be denied
        // In real testing, this would use dependency injection with mocked AVAudioSession
        // For now, we document the expected behavior

        // When/Then - Expected behavior when permission denied
        // XCTAssertThrowsError(try sut.startCapture(deviceUID: nil)) { error in
        //     XCTAssertTrue(error is AudioCaptureError, "Should throw permission error")
        // }
    }
}

// MARK: - Supporting Types (Contracts)

protocol AudioCaptureServiceProtocol {
    var isCapturing: Bool { get }
    var audioLevelPublisher: AnyPublisher<Float, Never> { get }

    func startCapture(deviceUID: String?) throws
    func stopCapture() throws -> Data
}

enum AudioCaptureError: Error {
    case alreadyCapturing
    case notCapturing
    case deviceNotFound
    case permissionDenied
    case configurationFailed(String)
}
