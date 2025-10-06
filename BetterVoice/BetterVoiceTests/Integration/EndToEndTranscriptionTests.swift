//
//  EndToEndTranscriptionTests.swift
//  BetterVoiceTests
//
//  Integration test for complete transcription workflow
//  Tests MUST FAIL until implementation (TDD Red phase)
//  Based on quickstart.md primary scenario
//

import XCTest
import Combine
@testable import BetterVoice

final class EndToEndTranscriptionTests: XCTestCase {
    var appState: AppState!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        appState = AppState()
        cancellables = []
    }

    override func tearDown() async throws {
        cancellables = nil
        appState = nil
        try await super.tearDown()
    }

    // MARK: - Primary Scenario: Gmail Email Composition (from quickstart.md)

    func testCompleteEmailTranscriptionWorkflow() async throws {
        // GIVEN: App is in ready state
        XCTAssertEqual(appState.currentStatus, .ready, "App should start in ready state")

        // Simulate Gmail being the frontmost app
        let gmailContext = DocumentTypeContext(
            id: UUID(),
            timestamp: Date(),
            frontmostAppBundleID: "com.google.Chrome",
            frontmostAppName: "Chrome",
            windowTitle: "Compose - Gmail",
            url: "https://mail.google.com/mail/u/0/#inbox?compose=new",
            detectedType: .email,
            detectionMethod: .urlAnalysis,
            confidence: 0.95
        )
        appState.currentDocumentContext = gmailContext

        // WHEN: User presses hotkey and speaks for 15 seconds
        let workflowStart = Date()

        // Step 1: Hotkey press starts recording
        try await appState.handleHotkeyPress()
        XCTAssertEqual(appState.currentStatus, .recording, "Should transition to recording")

        // Simulate 15 seconds of speech (test audio)
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms simulation

        // Step 2: Hotkey release stops recording and starts processing
        try await appState.handleHotkeyRelease()
        XCTAssertEqual(appState.currentStatus, .transcribing, "Should transition to transcribing")

        // Wait for transcription to complete
        await waitForStatus(.enhancing, timeout: 5.0)

        // Wait for enhancement to complete
        await waitForStatus(.pasting, timeout: 5.0)

        // Wait for paste to complete
        await waitForStatus(.ready, timeout: 2.0)

        let totalTime = Date().timeIntervalSince(workflowStart)

        // THEN: All requirements met
        XCTAssertLessThan(totalTime, 20.0, "Total flow should complete in <20s for 15s recording")

        // Verify clipboard has formatted email text
        let clipboardText = NSPasteboard.general.string(forType: .string)
        XCTAssertNotNil(clipboardText, "Clipboard should have text")
        XCTAssertTrue(clipboardText!.contains("Hi Sarah") || clipboardText!.contains("Dear"), "Should have email greeting")
        XCTAssertTrue(clipboardText!.contains("\n"), "Should have paragraphs")
        XCTAssertFalse(clipboardText!.contains("um"), "Should not contain fillers")

        // Verify final state
        XCTAssertEqual(appState.currentStatus, .ready, "Should return to ready state")
        XCTAssertNotNil(appState.lastTranscription, "Should have transcription record")
        XCTAssertNotNil(appState.lastEnhancement, "Should have enhancement record")
    }

    // MARK: - Phase Breakdown Tests

    func testHotkeyToRecordingPhase() async throws {
        // GIVEN
        XCTAssertEqual(appState.currentStatus, .ready)

        // WHEN
        let startTime = Date()
        try await appState.handleHotkeyPress()
        let elapsed = Date().timeIntervalSince(startTime)

        // THEN: PR-001 <100ms
        XCTAssertLessThan(elapsed, 0.1, "Hotkey response must be <100ms (PR-001)")
        XCTAssertEqual(appState.currentStatus, .recording)
        XCTAssertTrue(appState.isRecording, "Should be recording")
    }

    func testRecordingToTranscriptionPhase() async throws {
        // GIVEN: Recording in progress
        try await appState.handleHotkeyPress()
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms of audio

        // WHEN
        try await appState.handleHotkeyRelease()

        // THEN
        XCTAssertEqual(appState.currentStatus, .transcribing)
        XCTAssertNotNil(appState.currentAudioRecording, "Should have audio recording")
        XCTAssertGreaterThan(appState.currentAudioRecording!.duration, 0.4, "Should have ~500ms of audio")
    }

    func testTranscriptionToEnhancementPhase() async throws {
        // GIVEN: Transcription complete
        let mockTranscription = TranscriptionJob(
            id: UUID(),
            audioRecordingID: UUID(),
            modelSize: .base,
            detectedLanguage: "en",
            languageConfidence: 0.98,
            status: .completed,
            startTime: Date().addingTimeInterval(-2),
            endTime: Date(),
            rawTranscription: "hi sarah i wanted to follow up on our meeting yesterday thanks",
            error: nil
        )
        appState.currentTranscription = mockTranscription
        appState.currentStatus = .enhancing

        // WHEN: Enhancement runs
        await waitForStatus(.pasting, timeout: 3.0)

        // THEN
        XCTAssertNotNil(appState.currentEnhancement, "Should have enhancement result")
        XCTAssertTrue(appState.currentEnhancement!.enhancedText.contains("Hi"), "Should be capitalized")
        XCTAssertTrue(appState.currentEnhancement!.enhancedText.contains("Sarah"), "Should capitalize names")
    }

    func testEnhancementToPastePhase() async throws {
        // GIVEN: Enhancement complete
        let mockEnhancement = EnhancedText(
            id: UUID(),
            transcriptionJobID: UUID(),
            documentTypeContextID: UUID(),
            timestamp: Date(),
            originalText: "hi sarah thanks",
            enhancedText: "Hi Sarah,\n\nThanks for your help.\n\nBest regards,",
            appliedRules: ["Normalize", "Punctuate", "FormatEmail"],
            removedFillers: [],
            addedPunctuation: 3,
            formattingChanges: ["Greeting", "Paragraphs", "Closing"],
            usedCloudAPI: false,
            cloudProvider: nil,
            learningPatternsApplied: 0,
            confidence: 0.9
        )
        appState.currentEnhancement = mockEnhancement
        appState.currentStatus = .pasting

        // WHEN: Paste executes
        let startTime = Date()
        await waitForStatus(.ready, timeout: 1.0)
        let elapsed = Date().timeIntervalSince(startTime)

        // THEN: PR-003 <500ms
        XCTAssertLessThan(elapsed, 0.5, "Paste must complete in <500ms (PR-003)")

        let clipboardText = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(clipboardText, mockEnhancement.enhancedText, "Clipboard should match enhanced text")
    }

    // MARK: - Error Recovery

    func testRecoverFromTranscriptionError() async throws {
        // GIVEN: Recording fails
        try await appState.handleHotkeyPress()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Simulate transcription error
        appState.simulateError(TranscriptionError.modelNotLoaded)

        // WHEN
        await waitForStatus(.error, timeout: 1.0)

        // THEN
        XCTAssertEqual(appState.currentStatus, .error)
        XCTAssertNotNil(appState.lastError, "Should have error message")

        // Should be able to retry
        appState.clearError()
        XCTAssertEqual(appState.currentStatus, .ready, "Should return to ready after clearing error")
    }

    func testRecoverFromCloudAPIFailure() async throws {
        // GIVEN: Cloud API enabled but fails
        appState.preferences.externalLLMEnabled = true

        let mockContext = DocumentTypeContext(
            id: UUID(),
            timestamp: Date(),
            frontmostAppBundleID: "com.apple.mail",
            frontmostAppName: "Mail",
            windowTitle: nil,
            url: nil,
            detectedType: .email,
            detectionMethod: .bundleIDMapping,
            confidence: 0.95
        )
        appState.currentDocumentContext = mockContext

        // WHEN: Workflow runs with cloud failure
        try await appState.handleHotkeyPress()
        try await Task.sleep(nanoseconds: 100_000_000)
        try await appState.handleHotkeyRelease()

        await waitForStatus(.ready, timeout: 10.0)

        // THEN: Should fall back to local-only enhancement
        XCTAssertNotNil(appState.currentEnhancement, "Should have local enhancement")
        XCTAssertFalse(appState.currentEnhancement!.usedCloudAPI, "Should fall back to local")
    }

    // MARK: - Helper Methods

    private func waitForStatus(_ expectedStatus: AppStatus, timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if appState.currentStatus == expectedStatus {
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms polling
        }

        XCTFail("Timeout waiting for status \(expectedStatus), current: \(appState.currentStatus)")
    }
}

// MARK: - Supporting Types

enum AppStatus {
    case ready
    case recording
    case transcribing
    case enhancing
    case pasting
    case error
}

enum TranscriptionError: Error {
    case modelNotLoaded
    case audioCaptureFailed
    case transcriptionFailed
}
