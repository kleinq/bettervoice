//
//  HotkeyWorkflowTests.swift
//  BetterVoiceTests
//
//  Integration test for hotkey-driven recording workflow
//  Tests MUST FAIL until implementation (TDD Red phase)
//

import XCTest
import Combine
@testable import BetterVoice

final class HotkeyWorkflowTests: XCTestCase {
    var appState: AppState!
    var hotkeyManager: HotkeyManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        appState = AppState()
        hotkeyManager = HotkeyManager()
        cancellables = []
    }

    override func tearDown() async throws {
        hotkeyManager.unregister()
        cancellables = nil
        hotkeyManager = nil
        appState = nil
        try await super.tearDown()
    }

    // MARK: - Hotkey Press Starts Recording

    func testHotkeyPressStartsRecording() async throws {
        // GIVEN: App in ready state with hotkey registered
        XCTAssertEqual(appState.currentStatus, .ready)

        try hotkeyManager.register(keyCode: 61, modifiers: 0) // Right Option key

        // Setup callback to trigger app state
        hotkeyManager.onKeyPress = {
            Task {
                try? await self.appState.handleHotkeyPress()
            }
        }

        // WHEN: Hotkey pressed
        hotkeyManager.simulateKeyPress()

        // Wait for state transition
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // THEN: Recording should start
        XCTAssertEqual(appState.currentStatus, .recording, "Should transition to recording on hotkey press")
        XCTAssertTrue(appState.isRecording, "isRecording flag should be true")
        XCTAssertNotNil(appState.currentAudioRecording, "Should have active audio recording")
    }

    // MARK: - Hotkey Release Stops Recording

    func testHotkeyReleaseStopsRecording() async throws {
        // GIVEN: Recording in progress
        try hotkeyManager.register(keyCode: 61, modifiers: 0)

        hotkeyManager.onKeyPress = {
            Task {
                try? await self.appState.handleHotkeyPress()
            }
        }

        hotkeyManager.onKeyRelease = {
            Task {
                try? await self.appState.handleHotkeyRelease()
            }
        }

        // Start recording
        hotkeyManager.simulateKeyPress()
        try await Task.sleep(nanoseconds: 500_000_000) // Record 500ms

        XCTAssertEqual(appState.currentStatus, .recording)

        // WHEN: Hotkey released
        hotkeyManager.simulateKeyRelease()

        // Wait for transcription to start
        try await Task.sleep(nanoseconds: 200_000_000)

        // THEN: Should stop recording and start processing
        XCTAssertNotEqual(appState.currentStatus, .recording, "Should leave recording state")
        XCTAssertFalse(appState.isRecording, "isRecording flag should be false")
        XCTAssertEqual(appState.currentStatus, .transcribing, "Should start transcription")
    }

    // MARK: - Visual Feedback Updates (FR-010, FR-011)

    func testVisualFeedbackUpdatesDuringWorkflow() async throws {
        // GIVEN: Observable app state
        var statusChanges: [AppStatus] = []

        appState.$currentStatus
            .sink { status in
                statusChanges.append(status)
            }
            .store(in: &cancellables)

        try hotkeyManager.register(keyCode: 61, modifiers: 0)

        hotkeyManager.onKeyPress = {
            Task { try? await self.appState.handleHotkeyPress() }
        }

        hotkeyManager.onKeyRelease = {
            Task { try? await self.appState.handleHotkeyRelease() }
        }

        // WHEN: Complete workflow
        hotkeyManager.simulateKeyPress()
        try await Task.sleep(nanoseconds: 300_000_000)
        hotkeyManager.simulateKeyRelease()
        try await Task.sleep(nanoseconds: 100_000_000)

        // THEN: Should observe status transitions
        XCTAssertTrue(statusChanges.contains(.ready), "Should start at ready")
        XCTAssertTrue(statusChanges.contains(.recording), "Should transition to recording")
        XCTAssertTrue(statusChanges.contains(.transcribing), "Should transition to transcribing")

        // Verify menu bar icon changes (tracked by app state)
        XCTAssertNotNil(appState.currentMenuBarIcon, "Should have menu bar icon state")
    }

    // MARK: - Audio Cues Play at Correct Times (FR-014)

    func testAudioCuesPlayAtCorrectTimes() async throws {
        // GIVEN: Audio cues enabled
        appState.preferences.audioFeedbackEnabled = true

        var audioCuesPlayed: [String] = []

        // Mock audio cue playback tracking
        appState.onAudioCuePlayed = { cueName in
            audioCuesPlayed.append(cueName)
        }

        try hotkeyManager.register(keyCode: 61, modifiers: 0)

        hotkeyManager.onKeyPress = {
            Task { try? await self.appState.handleHotkeyPress() }
        }

        hotkeyManager.onKeyRelease = {
            Task { try? await self.appState.handleHotkeyRelease() }
        }

        // WHEN: Complete workflow
        hotkeyManager.simulateKeyPress()
        try await Task.sleep(nanoseconds: 100_000_000)

        hotkeyManager.simulateKeyRelease()
        try await Task.sleep(nanoseconds: 100_000_000)

        // THEN: Audio cues should play in order
        XCTAssertTrue(audioCuesPlayed.contains("recording-start"), "Should play start cue")
        XCTAssertTrue(audioCuesPlayed.contains("recording-stop"), "Should play stop cue")

        // Verify order
        let startIndex = audioCuesPlayed.firstIndex(of: "recording-start")
        let stopIndex = audioCuesPlayed.firstIndex(of: "recording-stop")

        XCTAssertNotNil(startIndex, "Start cue should be played")
        XCTAssertNotNil(stopIndex, "Stop cue should be played")
        XCTAssertLessThan(startIndex!, stopIndex!, "Start cue should play before stop cue")
    }

    // MARK: - Overlay Visibility (FR-013)

    func testRecordingOverlayAppearsAndDismisses() async throws {
        // GIVEN: Visual overlay enabled
        appState.preferences.visualOverlayEnabled = true

        try hotkeyManager.register(keyCode: 61, modifiers: 0)

        hotkeyManager.onKeyPress = {
            Task { try? await self.appState.handleHotkeyPress() }
        }

        hotkeyManager.onKeyRelease = {
            Task { try? await self.appState.handleHotkeyRelease() }
        }

        // WHEN: Start recording
        hotkeyManager.simulateKeyPress()
        try await Task.sleep(nanoseconds: 100_000_000)

        // THEN: Recording overlay should be visible
        XCTAssertTrue(appState.isRecordingOverlayVisible, "Recording overlay should appear")
        XCTAssertFalse(appState.isProcessingOverlayVisible, "Processing overlay should not appear yet")

        // WHEN: Stop recording
        hotkeyManager.simulateKeyRelease()
        try await Task.sleep(nanoseconds: 100_000_000)

        // THEN: Should switch to processing overlay
        XCTAssertFalse(appState.isRecordingOverlayVisible, "Recording overlay should dismiss")
        XCTAssertTrue(appState.isProcessingOverlayVisible, "Processing overlay should appear")
    }

    // MARK: - Waveform Visualization (FR-013)

    func testWaveformVisualizationUpdates() async throws {
        // GIVEN: Recording with audio level updates
        var audioLevels: [Float] = []

        appState.audioLevelPublisher
            .sink { level in
                audioLevels.append(level)
            }
            .store(in: &cancellables)

        try hotkeyManager.register(keyCode: 61, modifiers: 0)

        hotkeyManager.onKeyPress = {
            Task { try? await self.appState.handleHotkeyPress() }
        }

        // WHEN: Record with simulated audio
        hotkeyManager.simulateKeyPress()
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms of recording

        // THEN: Should receive audio level updates
        XCTAssertGreaterThan(audioLevels.count, 10, "Should receive multiple audio level updates (~60Hz)")
        XCTAssertTrue(audioLevels.allSatisfy { $0 >= 0.0 && $0 <= 1.0 }, "Audio levels should be normalized 0.0-1.0")

        hotkeyManager.simulateKeyRelease()
    }

    // MARK: - Timer Display Updates (FR-013)

    func testTimerDisplayUpdates() async throws {
        // GIVEN: Recording in progress
        try hotkeyManager.register(keyCode: 61, modifiers: 0)

        hotkeyManager.onKeyPress = {
            Task { try? await self.appState.handleHotkeyPress() }
        }

        // WHEN: Record for 2 seconds
        hotkeyManager.simulateKeyPress()

        let startTime = Date()
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        let recordingDuration = appState.currentRecordingDuration

        // THEN: Timer should show elapsed time
        XCTAssertGreaterThan(recordingDuration, 1.5, "Timer should show ~2 seconds")
        XCTAssertLessThan(recordingDuration, 2.5, "Timer should be approximately 2 seconds")

        hotkeyManager.simulateKeyRelease()
    }

    // MARK: - Hotkey Configuration Changes (FR-012)

    func testHotkeyConfigurationChanges() async throws {
        // GIVEN: Hotkey registered with default key
        try hotkeyManager.register(keyCode: 61, modifiers: 0) // Right Option

        // WHEN: User changes hotkey in preferences
        appState.preferences.hotkeyKeyCode = 49 // Space bar
        appState.preferences.hotkeyModifiers = UInt32(cmdKey) // Cmd+Space

        // Should unregister old and register new
        try await appState.updateHotkeyRegistration()

        // THEN: New hotkey should be active
        XCTAssertTrue(hotkeyManager.isRegistered, "Should still be registered")

        // Old hotkey should not trigger (can't easily test without real key events)
        // New hotkey should trigger (verified by isRegistered)
    }

    // MARK: - Multiple Press/Release Cycles

    func testMultiplePressReleaseCycles() async throws {
        // GIVEN: Hotkey registered
        try hotkeyManager.register(keyCode: 61, modifiers: 0)

        hotkeyManager.onKeyPress = {
            Task { try? await self.appState.handleHotkeyPress() }
        }

        hotkeyManager.onKeyRelease = {
            Task { try? await self.appState.handleHotkeyRelease() }
        }

        // WHEN: Multiple recording cycles
        for i in 1...3 {
            hotkeyManager.simulateKeyPress()
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms recording

            XCTAssertEqual(appState.currentStatus, .recording, "Cycle \(i): Should be recording")

            hotkeyManager.simulateKeyRelease()
            try await Task.sleep(nanoseconds: 100_000_000)

            XCTAssertNotEqual(appState.currentStatus, .recording, "Cycle \(i): Should stop recording")

            // Wait for workflow to complete before next cycle
            await waitForStatus(.ready, timeout: 5.0)
        }

        // THEN: All cycles should complete successfully
        XCTAssertEqual(appState.currentStatus, .ready, "Should return to ready after all cycles")
    }

    // MARK: - Rapid Press/Release (Edge Case)

    func testRapidPressReleaseHandling() async throws {
        // GIVEN: Hotkey registered
        try hotkeyManager.register(keyCode: 61, modifiers: 0)

        hotkeyManager.onKeyPress = {
            Task { try? await self.appState.handleHotkeyPress() }
        }

        hotkeyManager.onKeyRelease = {
            Task { try? await self.appState.handleHotkeyRelease() }
        }

        // WHEN: Very rapid press/release (accidental tap)
        hotkeyManager.simulateKeyPress()
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms - very short
        hotkeyManager.simulateKeyRelease()

        try await Task.sleep(nanoseconds: 200_000_000)

        // THEN: Should handle gracefully (may reject if too short)
        // System should either:
        // 1. Record short audio and process it, or
        // 2. Reject recording if below minimum duration
        XCTAssertTrue(
            appState.currentStatus == .ready || appState.currentStatus == .transcribing,
            "Should handle rapid tap gracefully"
        )
    }

    // MARK: - Helper Methods

    private func waitForStatus(_ expectedStatus: AppStatus, timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if appState.currentStatus == expectedStatus {
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTFail("Timeout waiting for status \(expectedStatus), current: \(appState.currentStatus)")
    }
}
