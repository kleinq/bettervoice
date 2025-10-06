//
//  LearningPatternTests.swift
//  BetterVoiceTests
//
//  Unit tests for LearningPattern model
//  Tests learning system patterns stored in GRDB SQLite
//

import XCTest
@testable import BetterVoice

final class LearningPatternTests: XCTestCase {

    func testLearningPatternIsEncodableAndDecodable() throws {
        // Given
        let pattern = LearningPattern(
            id: 123,
            documentType: .email,
            originalText: "thanks",
            editedText: "thank you",
            frequency: 5,
            lastSeen: Date(),
            confidence: 0.8
        )

        // When
        let encoded = try JSONEncoder().encode(pattern)
        let decoded = try JSONDecoder().decode(LearningPattern.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.id, pattern.id)
        XCTAssertEqual(decoded.originalText, pattern.originalText)
        XCTAssertEqual(decoded.editedText, pattern.editedText)
        XCTAssertEqual(decoded.frequency, pattern.frequency)
        XCTAssertEqual(decoded.documentType, pattern.documentType)
    }

    func testIsTrustedProperty() {
        // Given: High confidence (≥0.7)
        let trusted = LearningPattern(
            id: 1,
            documentType: .email,
            originalText: "bye",
            editedText: "best regards",
            frequency: 10,
            lastSeen: Date(),
            confidence: 0.9
        )

        // Then
        XCTAssertTrue(trusted.isTrusted, "Confidence ≥0.7 should be trusted")
        XCTAssertEqual(trusted.confidence, 0.9, accuracy: 0.01)

        // Given: Edge case exactly 0.7
        let edgeTrusted = LearningPattern(
            documentType: .message,
            originalText: "ok",
            editedText: "okay",
            frequency: 3,
            confidence: 0.7
        )

        // Then
        XCTAssertTrue(edgeTrusted.isTrusted, "Confidence exactly 0.7 should be trusted")

        // Given: Low confidence (<0.7)
        let untrusted = LearningPattern(
            documentType: .document,
            originalText: "test",
            editedText: "testing",
            frequency: 1,
            confidence: 0.5
        )

        // Then
        XCTAssertFalse(untrusted.isTrusted, "Confidence <0.7 should not be trusted")
    }

    func testIsSignificantEditProperty() {
        // Given: Significant edit (≥10% change)
        let significant = LearningPattern(
            documentType: .email,
            originalText: "thanks for your help",
            editedText: "Thank you very much for your assistance",
            frequency: 3
        )

        // Then: 40 chars vs 20 chars = 100% change
        XCTAssertTrue(significant.isSignificantEdit, "≥10% change should be significant")

        // Given: Minor edit (<10% change)
        let minor = LearningPattern(
            documentType: .message,
            originalText: "Hello there",
            editedText: "Hello there!",
            frequency: 2
        )

        // Then: 12 vs 11 chars = ~9% change
        XCTAssertFalse(minor.isSignificantEdit, "<10% change should not be significant")

        // Given: Edge case - empty original
        let emptyOriginal = LearningPattern(
            documentType: .unknown,
            originalText: "",
            editedText: "something",
            frequency: 1
        )

        // Then
        XCTAssertFalse(emptyOriginal.isSignificantEdit, "Empty original should return false")
    }

    func testConfidenceCalculation() {
        // Given: Low frequency
        var lowFreq = LearningPattern(
            documentType: .email,
            originalText: "hi",
            editedText: "hello",
            frequency: 1
        )

        // When
        lowFreq.updateConfidence()

        // Then: log10(2)/log10(11) ≈ 0.29
        XCTAssertLessThan(lowFreq.confidence, 0.5)

        // Given: Medium frequency
        var mediumFreq = LearningPattern(
            documentType: .email,
            originalText: "thanks",
            editedText: "thank you",
            frequency: 5
        )

        // When
        mediumFreq.updateConfidence()

        // Then: log10(6)/log10(11) ≈ 0.75
        XCTAssertGreaterThan(mediumFreq.confidence, 0.7)
        XCTAssertLessThan(mediumFreq.confidence, 0.8)

        // Given: High frequency (10 = max confidence)
        var highFreq = LearningPattern(
            documentType: .message,
            originalText: "ok",
            editedText: "okay",
            frequency: 10
        )

        // When
        highFreq.updateConfidence()

        // Then: Should cap at 1.0
        XCTAssertEqual(highFreq.confidence, 1.0, accuracy: 0.01)

        // Given: Very high frequency
        var veryHighFreq = LearningPattern(
            documentType: .email,
            originalText: "bye",
            editedText: "goodbye",
            frequency: 100
        )

        // When
        veryHighFreq.updateConfidence()

        // Then: Should still cap at 1.0
        XCTAssertEqual(veryHighFreq.confidence, 1.0, accuracy: 0.01)
    }

    func testFrequencyIncrement() {
        // Given
        var pattern = LearningPattern(
            documentType: .email,
            originalText: "test",
            editedText: "TEST",
            frequency: 1
        )

        // When
        pattern.frequency += 1

        // Then
        XCTAssertEqual(pattern.frequency, 2)
    }

    func testGRDBPersistableRecord() {
        // Given
        let pattern = LearningPattern(
            id: nil, // Auto-generated by database
            documentType: .email,
            originalText: "hi",
            editedText: "hello",
            frequency: 1
        )

        // Then: Should have table name
        XCTAssertEqual(LearningPattern.databaseTableName, "learning_patterns")
        XCTAssertNil(pattern.id, "New patterns should have nil ID before insertion")
    }

    func testDocumentTypeSpecificity() {
        // Given: Email pattern
        let emailPattern = LearningPattern(
            documentType: .email,
            originalText: "thanks",
            editedText: "Thank you for your time.\n\nBest regards",
            frequency: 5,
            confidence: 0.85
        )

        // Then
        XCTAssertEqual(emailPattern.documentType, .email)
        XCTAssertTrue(emailPattern.isTrusted)

        // Given: Message pattern
        let messagePattern = LearningPattern(
            documentType: .message,
            originalText: "thanks",
            editedText: "thanks!",
            frequency: 8,
            confidence: 0.95
        )

        // Then: Same original but different edits by context
        XCTAssertEqual(messagePattern.documentType, .message)
        XCTAssertNotEqual(emailPattern.editedText, messagePattern.editedText)
    }

    func testDefaultValues() {
        // Given: Pattern with defaults
        let pattern = LearningPattern(
            documentType: .document,
            originalText: "test",
            editedText: "Test."
        )

        // Then
        XCTAssertNil(pattern.id)
        XCTAssertEqual(pattern.frequency, 1, "Default frequency should be 1")
        XCTAssertEqual(pattern.confidence, 1.0, accuracy: 0.01, "Default confidence should be 1.0")
        XCTAssertNotNil(pattern.lastSeen, "lastSeen should default to now")
    }

    func testTimestampTracking() {
        // Given
        let before = Date()
        let pattern = LearningPattern(
            documentType: .email,
            originalText: "hi",
            editedText: "hello"
        )
        let after = Date()

        // Then
        XCTAssertGreaterThanOrEqual(pattern.lastSeen, before)
        XCTAssertLessThanOrEqual(pattern.lastSeen, after)
    }
}
