//
//  LearningSystemTests.swift
//  BetterVoiceTests
//
//  Integration test for learning system workflow
//  Tests MUST FAIL until implementation (TDD Red phase)
//

import XCTest
import Combine
@testable import BetterVoice

final class LearningSystemTests: XCTestCase {
    var appState: AppState!
    var learningService: LearningService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        appState = AppState()
        learningService = try await LearningService()
        cancellables = []
    }

    override func tearDown() async throws {
        try await learningService.clearAllPatterns()
        cancellables = nil
        learningService = nil
        appState = nil
        try await super.tearDown()
    }

    // MARK: - Complete Learning Workflow (QR-004)

    func testCompleteLearningWorkflow() async throws {
        // GIVEN: User performs transcription with email context
        let emailContext = DocumentTypeContext(
            id: UUID(),
            timestamp: Date(),
            frontmostAppBundleID: "com.apple.mail",
            frontmostAppName: "Mail",
            windowTitle: "New Message",
            url: nil,
            detectedType: .email,
            detectionMethod: .bundleIDMapping,
            confidence: 0.95
        )
        appState.currentDocumentContext = emailContext

        // Initial transcription: "thanks for your help"
        let originalText = "thanks for your help"

        // Simulate complete workflow
        try await appState.handleHotkeyPress()
        appState.simulateTranscription(text: originalText)
        try await appState.handleHotkeyRelease()

        await waitForPasteComplete(timeout: 5.0)

        // WHEN: User edits pasted text to "thank you for your assistance"
        let editedText = "thank you for your assistance"
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms delay

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(editedText, forType: .string)

        // Wait for learning observation to complete (10 second window from FR-017)
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2s wait

        // THEN: Pattern should be stored
        let patterns = try await learningService.findSimilarPatterns(
            text: originalText,
            documentType: .email,
            threshold: 0.5
        )

        XCTAssertGreaterThan(patterns.count, 0, "Should store learning pattern")
        XCTAssertEqual(patterns.first?.documentType, .email)
        XCTAssertTrue(patterns.first?.originalText.contains("thanks") ?? false)
    }

    // MARK: - Pattern Application on Subsequent Transcriptions

    func testPatternApplicationOnSubsequentTranscription() async throws {
        // GIVEN: Pre-existing high-confidence pattern
        let pattern = LearningPattern(
            id: UUID(),
            documentType: .email,
            originalText: "thanks",
            editedText: "thank you",
            editDistance: 7,
            frequency: 5, // High frequency
            firstSeen: Date().addingTimeInterval(-86400 * 7), // 7 days ago
            lastSeen: Date(),
            confidence: 0.8, // High confidence
            metadata: nil
        )
        try await learningService.storePattern(pattern)

        // Set email context
        appState.currentDocumentContext = DocumentTypeContext(
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

        // Enable learning system
        appState.preferences.learningSystemEnabled = true

        // WHEN: New transcription with "thanks"
        try await appState.handleHotkeyPress()
        appState.simulateTranscription(text: "thanks for everything")
        try await appState.handleHotkeyRelease()

        await waitForPasteComplete(timeout: 5.0)

        // THEN: Should apply learned pattern
        let clipboardText = NSPasteboard.general.string(forType: .string)
        XCTAssertTrue(clipboardText?.contains("thank you") ?? false, "Should apply learned pattern")
        XCTAssertFalse(clipboardText?.contains("thanks") ?? true, "Should replace original")

        // Verify enhancement metadata
        XCTAssertGreaterThan(appState.currentEnhancement?.learningPatternsApplied ?? 0, 0, "Should track applied patterns")
    }

    // MARK: - Confidence Increases with Frequency

    func testConfidenceIncreasesWithFrequency() async throws {
        // GIVEN: Initial low-confidence pattern
        let initialPattern = LearningPattern(
            id: UUID(),
            documentType: .email,
            originalText: "bye",
            editedText: "best regards",
            editDistance: 8,
            frequency: 1,
            firstSeen: Date(),
            lastSeen: Date(),
            confidence: 0.2, // Low initial confidence
            metadata: nil
        )
        try await learningService.storePattern(initialPattern)

        // WHEN: Same edit observed 4 more times
        for _ in 0..<4 {
            appState.currentDocumentContext = DocumentTypeContext(
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

            try await appState.handleHotkeyPress()
            appState.simulateTranscription(text: "bye")
            try await appState.handleHotkeyRelease()

            await waitForPasteComplete(timeout: 3.0)

            // Simulate user edit
            try await Task.sleep(nanoseconds: 500_000_000)
            NSPasteboard.general.setString("best regards", forType: .string)
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        // THEN: Confidence should increase
        let updatedPattern = try await learningService.getPattern(id: initialPattern.id)
        XCTAssertGreaterThan(updatedPattern?.frequency ?? 0, 1, "Frequency should increase")
        XCTAssertGreaterThan(updatedPattern?.confidence ?? 0, 0.2, "Confidence should increase with frequency")
    }

    // MARK: - QR-004: Reduction in User Edits Over Time

    func testReductionInUserEditsOverTime() async throws {
        // GIVEN: Pattern that gets applied after learning
        let pattern = LearningPattern(
            id: UUID(),
            documentType: .message,
            originalText: "lol",
            editedText: "haha",
            editDistance: 3,
            frequency: 3,
            firstSeen: Date().addingTimeInterval(-86400),
            lastSeen: Date(),
            confidence: 0.6,
            metadata: nil
        )
        try await learningService.storePattern(pattern)

        appState.currentDocumentContext = DocumentTypeContext(
            id: UUID(),
            timestamp: Date(),
            frontmostAppBundleID: "com.tinyspeck.slackmacgap",
            frontmostAppName: "Slack",
            windowTitle: nil,
            url: nil,
            detectedType: .message,
            detectionMethod: .bundleIDMapping,
            confidence: 0.95
        )

        appState.preferences.learningSystemEnabled = true

        // WHEN: Transcribe text containing learned pattern
        try await appState.handleHotkeyPress()
        appState.simulateTranscription(text: "that's so funny lol")
        try await appState.handleHotkeyRelease()

        await waitForPasteComplete(timeout: 3.0)

        // THEN: Should already have learned replacement (no edit needed)
        let clipboardText = NSPasteboard.general.string(forType: .string)
        XCTAssertTrue(clipboardText?.contains("haha") ?? false, "Should apply learned pattern automatically")
        XCTAssertFalse(clipboardText?.contains("lol") ?? true, "Should not require user to edit")

        // Demonstrates QR-004: System learns from edits and applies them automatically,
        // reducing the need for users to make the same corrections repeatedly
    }

    // MARK: - Document Type Specificity

    func testPatternsAreDocumentTypeSpecific() async throws {
        // GIVEN: Pattern for emails only
        let emailPattern = LearningPattern(
            id: UUID(),
            documentType: .email,
            originalText: "hi",
            editedText: "dear sir or madam",
            editDistance: 15,
            frequency: 5,
            firstSeen: Date().addingTimeInterval(-86400 * 7),
            lastSeen: Date(),
            confidence: 0.8,
            metadata: nil
        )
        try await learningService.storePattern(emailPattern)

        // WHEN: Transcribe in message context (not email)
        appState.currentDocumentContext = DocumentTypeContext(
            id: UUID(),
            timestamp: Date(),
            frontmostAppBundleID: "com.tinyspeck.slackmacgap",
            frontmostAppName: "Slack",
            windowTitle: nil,
            url: nil,
            detectedType: .message,
            detectionMethod: .bundleIDMapping,
            confidence: 0.95
        )

        appState.preferences.learningSystemEnabled = true

        try await appState.handleHotkeyPress()
        appState.simulateTranscription(text: "hi everyone")
        try await appState.handleHotkeyRelease()

        await waitForPasteComplete(timeout: 3.0)

        // THEN: Email pattern should NOT be applied to messages
        let clipboardText = NSPasteboard.general.string(forType: .string)
        XCTAssertFalse(clipboardText?.contains("dear sir or madam") ?? false, "Should not apply email pattern to messages")
        XCTAssertTrue(clipboardText?.contains("hi") || clipboardText?.contains("Hi") ?? false, "Should keep casual greeting")
    }

    // MARK: - Learning System Toggle

    func testLearningSystemCanBeDisabled() async throws {
        // GIVEN: Pattern exists but learning is disabled
        let pattern = LearningPattern(
            id: UUID(),
            documentType: .email,
            originalText: "thanks",
            editedText: "thank you",
            editDistance: 7,
            frequency: 5,
            firstSeen: Date().addingTimeInterval(-86400 * 7),
            lastSeen: Date(),
            confidence: 0.8,
            metadata: nil
        )
        try await learningService.storePattern(pattern)

        appState.currentDocumentContext = DocumentTypeContext(
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

        // WHEN: Learning system disabled
        appState.preferences.learningSystemEnabled = false

        try await appState.handleHotkeyPress()
        appState.simulateTranscription(text: "thanks for your help")
        try await appState.handleHotkeyRelease()

        await waitForPasteComplete(timeout: 3.0)

        // THEN: Pattern should NOT be applied
        let clipboardText = NSPasteboard.general.string(forType: .string)
        XCTAssertTrue(clipboardText?.contains("thanks") || clipboardText?.contains("Thanks") ?? false, "Should not apply pattern when disabled")

        XCTAssertEqual(appState.currentEnhancement?.learningPatternsApplied ?? 0, 0, "Should not apply any patterns")
    }

    // MARK: - Helper Methods

    private func waitForPasteComplete(timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if appState.currentStatus == .ready && appState.currentEnhancement != nil {
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTFail("Timeout waiting for paste to complete")
    }
}
