//
//  LearningContractTests.swift
//  BetterVoiceTests
//
//  Contract tests for LearningService
//  Tests MUST FAIL until implementation (TDD Red phase)
//

import XCTest
import Combine
@testable import BetterVoice

final class LearningContractTests: XCTestCase {
    var sut: LearningService!

    override func setUp() async throws {
        try await super.setUp()
        sut = try await LearningService()
    }

    override func tearDown() async throws {
        try await sut.clearAllPatterns() // Clean up test data
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Contract: Observe monitors clipboard for edits

    func testObserveMonitorsClipboardForEdits() async throws {
        // Given
        let originalText = "Thanks for your help"
        let editedText = "Thank you for your assistance"
        let documentType: DocumentType = .email

        // Start observing
        let observationTask = Task {
            try await sut.observe(
                originalText: originalText,
                documentType: documentType,
                timeoutSeconds: 2
            )
        }

        // When: Simulate user editing (change clipboard after 500ms)
        try await Task.sleep(nanoseconds: 500_000_000)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(editedText, forType: .string)

        // Wait for observation to complete
        try await observationTask.value

        // Then: Pattern should be stored
        let patterns = try await sut.findSimilarPatterns(
            text: originalText,
            documentType: documentType,
            threshold: 0.5
        )

        XCTAssertGreaterThan(patterns.count, 0, "Should have stored learning pattern")
        XCTAssertEqual(patterns.first?.originalText, originalText)
        XCTAssertEqual(patterns.first?.editedText, editedText)
    }

    // MARK: - Contract: findSimilarPatterns uses edit distance matching

    func testFindSimilarPatternsUsesEditDistanceMatching() async throws {
        // Given: Store a known pattern
        let pattern = LearningPattern(
            id: UUID(),
            documentType: .email,
            originalText: "thanks",
            editedText: "thank you",
            editDistance: 7,
            frequency: 3,
            firstSeen: Date().addingTimeInterval(-86400),
            lastSeen: Date(),
            confidence: 0.6,
            metadata: nil
        )
        try await sut.storePattern(pattern)

        // When: Search with similar but not identical text
        let similarText = "thanks for everything" // Contains "thanks"
        let matches = try await sut.findSimilarPatterns(
            text: similarText,
            documentType: .email,
            threshold: 0.7
        )

        // Then
        XCTAssertGreaterThan(matches.count, 0, "Should find similar patterns")
        XCTAssertTrue(matches.contains { $0.originalText == "thanks" }, "Should match 'thanks'")
    }

    // MARK: - Contract: applyLearned modifies text based on patterns

    func testApplyLearnedModifiesTextBasedOnPatterns() async throws {
        // Given: High-confidence pattern
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
        try await sut.storePattern(pattern)

        let originalText = "thanks for your help"

        // When
        let modifiedText = try await sut.applyLearned(
            text: originalText,
            documentType: .email,
            patterns: [pattern]
        )

        // Then
        XCTAssertNotEqual(modifiedText, originalText, "Text should be modified")
        XCTAssertTrue(modifiedText.contains("thank you"), "Should apply learned pattern")
        XCTAssertFalse(modifiedText.contains("thanks"), "Should replace original")
    }

    // MARK: - Contract: Pattern storage in SQLite database

    func testPatternStorageInSQLiteDatabase() async throws {
        // Given
        let pattern = LearningPattern(
            id: UUID(),
            documentType: .email,
            originalText: "see you soon",
            editedText: "looking forward to seeing you",
            editDistance: 20,
            frequency: 1,
            firstSeen: Date(),
            lastSeen: Date(),
            confidence: 0.3,
            metadata: ["source": "manual"]
        )

        // When
        try await sut.storePattern(pattern)

        // Then: Retrieve from database
        let retrieved = try await sut.getPattern(id: pattern.id)
        XCTAssertNotNil(retrieved, "Pattern should be stored in database")
        XCTAssertEqual(retrieved?.originalText, pattern.originalText)
        XCTAssertEqual(retrieved?.editedText, pattern.editedText)
        XCTAssertEqual(retrieved?.frequency, 1)
    }

    // MARK: - Pattern Frequency and Confidence

    func testPatternFrequencyIncrementsOnRepeat() async throws {
        // Given
        let originalPattern = LearningPattern(
            id: UUID(),
            documentType: .email,
            originalText: "bye",
            editedText: "best regards",
            editDistance: 8,
            frequency: 1,
            firstSeen: Date(),
            lastSeen: Date(),
            confidence: 0.2,
            metadata: nil
        )
        try await sut.storePattern(originalPattern)

        // When: Observe same edit multiple times
        for _ in 0..<3 {
            try await sut.observe(
                originalText: "bye",
                documentType: .email,
                timeoutSeconds: 1
            )

            // Simulate edit
            try await Task.sleep(nanoseconds: 100_000_000)
            NSPasteboard.general.setString("best regards", forType: .string)
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        // Then: Frequency should increase
        let updated = try await sut.getPattern(id: originalPattern.id)
        XCTAssertGreaterThan(updated?.frequency ?? 0, 1, "Frequency should increment")
        XCTAssertGreaterThan(updated?.confidence ?? 0, 0.2, "Confidence should increase with frequency")
    }

    // MARK: - Document Type Filtering

    func testFindSimilarPatternsFiltersByDocumentType() async throws {
        // Given: Patterns for different document types
        let emailPattern = LearningPattern(
            id: UUID(),
            documentType: .email,
            originalText: "hi",
            editedText: "dear sir or madam",
            editDistance: 15,
            frequency: 3,
            firstSeen: Date(),
            lastSeen: Date(),
            confidence: 0.6,
            metadata: nil
        )

        let messagePattern = LearningPattern(
            id: UUID(),
            documentType: .message,
            originalText: "hi",
            editedText: "hey",
            editDistance: 2,
            frequency: 5,
            firstSeen: Date(),
            lastSeen: Date(),
            confidence: 0.8,
            metadata: nil
        )

        try await sut.storePattern(emailPattern)
        try await sut.storePattern(messagePattern)

        // When: Search for email patterns only
        let emailMatches = try await sut.findSimilarPatterns(
            text: "hi there",
            documentType: .email,
            threshold: 0.5
        )

        // Then
        XCTAssertTrue(emailMatches.contains { $0.documentType == .email }, "Should find email pattern")
        XCTAssertFalse(emailMatches.contains { $0.documentType == .message }, "Should not find message pattern")
    }

    // MARK: - Confidence Thresholding

    func testLowConfidencePatternsNotApplied() async throws {
        // Given: Low confidence pattern (frequency = 1)
        let lowConfPattern = LearningPattern(
            id: UUID(),
            documentType: .email,
            originalText: "test",
            editedText: "examination",
            editDistance: 8,
            frequency: 1,
            firstSeen: Date(),
            lastSeen: Date(),
            confidence: 0.1,
            metadata: nil
        )
        try await sut.storePattern(lowConfPattern)

        let originalText = "this is a test message"

        // When
        let modifiedText = try await sut.applyLearned(
            text: originalText,
            documentType: .email,
            patterns: [lowConfPattern],
            minConfidence: 0.3 // Require at least 30% confidence
        )

        // Then: Should not apply low-confidence pattern
        XCTAssertEqual(modifiedText, originalText, "Should not apply low confidence pattern")
    }

    // MARK: - Significant Edit Detection

    func testOnlyStoresSignificantEdits() async throws {
        // Given
        let originalText = "hello"

        // When: Simulate minor typo fix (not significant)
        let observationTask = Task {
            try await sut.observe(
                originalText: originalText,
                documentType: .email,
                timeoutSeconds: 1
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        NSPasteboard.general.setString("Hello", forType: .string) // Only capitalization
        try await observationTask.value

        // Then: Should not store trivial edit
        let patterns = try await sut.findSimilarPatterns(
            text: originalText,
            documentType: .email,
            threshold: 0.9
        )

        XCTAssertEqual(patterns.count, 0, "Should not store trivial edits (<10% change)")
    }

    // MARK: - Pattern Pruning

    func testOldLowConfidencePatternsArePruned() async throws {
        // Given: Old pattern with low confidence
        let oldPattern = LearningPattern(
            id: UUID(),
            documentType: .email,
            originalText: "old pattern",
            editedText: "very old pattern",
            editDistance: 5,
            frequency: 1,
            firstSeen: Date().addingTimeInterval(-86400 * 35), // 35 days ago
            lastSeen: Date().addingTimeInterval(-86400 * 32), // 32 days ago
            confidence: 0.2,
            metadata: nil
        )
        try await sut.storePattern(oldPattern)

        // When: Run pruning
        try await sut.pruneOldPatterns(olderThanDays: 30, minConfidence: 0.3)

        // Then: Should be removed
        let retrieved = try await sut.getPattern(id: oldPattern.id)
        XCTAssertNil(retrieved, "Old low-confidence pattern should be pruned")
    }
}

// MARK: - Supporting Types (Contracts)

protocol LearningServiceProtocol {
    func observe(originalText: String, documentType: DocumentType, timeoutSeconds: Int) async throws
    func findSimilarPatterns(text: String, documentType: DocumentType, threshold: Double) async throws -> [LearningPattern]
    func applyLearned(text: String, documentType: DocumentType, patterns: [LearningPattern], minConfidence: Float?) async throws -> String
    func storePattern(_ pattern: LearningPattern) async throws
    func getPattern(id: UUID) async throws -> LearningPattern?
    func clearAllPatterns() async throws
    func pruneOldPatterns(olderThanDays: Int, minConfidence: Float) async throws
}
