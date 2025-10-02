//
//  EnhancedTextTests.swift
//  BetterVoiceTests
//
//  Unit tests for EnhancedText model
//  Tests enhancement tracking and cloud API metadata
//

import XCTest
@testable import BetterVoice

final class EnhancedTextTests: XCTestCase {

    func testEnhancedTextIsEncodableAndDecodable() throws {
        // Given
        let enhanced = EnhancedText(
            originalText: "um so like this is a test you know",
            enhancedText: "This is a test.",
            documentType: .email,
            appliedRules: ["remove_fillers", "punctuation", "capitalization"],
            learnedPatternsApplied: 2,
            cloudEnhanced: false
        )

        // When
        let encoded = try JSONEncoder().encode(enhanced)
        let decoded = try JSONDecoder().decode(EnhancedText.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.originalText, enhanced.originalText)
        XCTAssertEqual(decoded.enhancedText, enhanced.enhancedText)
        XCTAssertEqual(decoded.documentType, enhanced.documentType)
        XCTAssertEqual(decoded.appliedRules.count, 3)
        XCTAssertEqual(decoded.learnedPatternsApplied, 2)
        XCTAssertFalse(decoded.cloudEnhanced)
    }

    func testImprovementRatio() {
        // Given: Text shortened by removing fillers
        let shortened = EnhancedText(
            originalText: "um so like this is a test you know right",
            enhancedText: "This is a test.",
            documentType: .message,
            appliedRules: ["remove_fillers"]
        )

        // When
        let ratio = shortened.improvementRatio

        // Then: Ratio should be positive (shortened)
        XCTAssertGreaterThan(ratio, 0.0)
        XCTAssertLessThan(ratio, 1.0) // Original was longer

        // Given: Text expanded (added punctuation/formatting)
        let expanded = EnhancedText(
            originalText: "test",
            enhancedText: "This is a test.",
            documentType: .email,
            appliedRules: ["expand", "punctuation"]
        )

        // When
        let expandRatio = expanded.improvementRatio

        // Then: Ratio should reflect expansion
        XCTAssertGreaterThan(expandRatio, 0.0)

        // Given: Minimal change
        let minimal = EnhancedText(
            originalText: "This is a test.",
            enhancedText: "This is a test.",
            documentType: .document
        )

        // When
        let minimalRatio = minimal.improvementRatio

        // Then: Ratio should be near zero
        XCTAssertEqual(minimalRatio, 0.0, accuracy: 0.01)
    }

    func testCloudEnhancement() {
        // Given: Local-only enhancement
        let localEnhanced = EnhancedText(
            originalText: "test input",
            enhancedText: "Test input.",
            documentType: .message,
            appliedRules: ["capitalization", "punctuation"],
            cloudEnhanced: false,
            cloudProvider: nil
        )

        // Then
        XCTAssertFalse(localEnhanced.cloudEnhanced)
        XCTAssertNil(localEnhanced.cloudProvider)

        // Given: Cloud-enhanced via Claude
        let cloudEnhanced = EnhancedText(
            originalText: "make this sound professional for email",
            enhancedText: "I would like to request your assistance with the following matter.",
            documentType: .email,
            appliedRules: ["cloud_enhancement"],
            cloudEnhanced: true,
            cloudProvider: "Claude"
        )

        // Then
        XCTAssertTrue(cloudEnhanced.cloudEnhanced)
        XCTAssertEqual(cloudEnhanced.cloudProvider, "Claude")
    }

    func testAppliedRulesTracking() {
        // Given: 6-stage enhancement pipeline (spec.md 4.2.2)
        let enhanced = EnhancedText(
            originalText: "um hey can you send me that file you know the one from yesterday",
            enhancedText: "Hey, can you send me that file from yesterday?",
            documentType: .message,
            appliedRules: [
                "normalize",
                "remove_fillers",
                "punctuation",
                "format_message",
                "learning_pattern_1",
                "learning_pattern_2"
            ],
            learnedPatternsApplied: 2
        )

        // Then
        XCTAssertEqual(enhanced.appliedRules.count, 6)
        XCTAssertTrue(enhanced.appliedRules.contains("remove_fillers"))
        XCTAssertTrue(enhanced.appliedRules.contains("punctuation"))
        XCTAssertEqual(enhanced.learnedPatternsApplied, 2)
    }

    func testDocumentTypeSpecificFormatting() {
        // Given: Email formatting
        let emailEnhanced = EnhancedText(
            originalText: "hey just wanted to follow up on that thing",
            enhancedText: "Hello,\n\nI wanted to follow up on our previous discussion.\n\nBest regards",
            documentType: .email,
            appliedRules: ["format_email", "add_greeting", "add_closing"]
        )

        // Then
        XCTAssertEqual(emailEnhanced.documentType, .email)
        XCTAssertTrue(emailEnhanced.appliedRules.contains("format_email"))
        XCTAssertGreaterThan(emailEnhanced.enhancedText.count, emailEnhanced.originalText.count)

        // Given: Search query formatting
        let searchEnhanced = EnhancedText(
            originalText: "um like how do you make a really good chocolate cake you know",
            enhancedText: "chocolate cake recipe",
            documentType: .searchQuery,
            appliedRules: ["extract_keywords", "remove_fillers"]
        )

        // Then
        XCTAssertEqual(searchEnhanced.documentType, .searchQuery)
        XCTAssertLessThan(searchEnhanced.enhancedText.count, searchEnhanced.originalText.count)
    }

    func testTimestampTracking() {
        // Given
        let before = Date()
        let enhanced = EnhancedText(
            originalText: "test",
            enhancedText: "Test.",
            documentType: .document
        )
        let after = Date()

        // Then
        XCTAssertGreaterThanOrEqual(enhanced.timestamp, before)
        XCTAssertLessThanOrEqual(enhanced.timestamp, after)
    }

    func testEmptyOriginalText() {
        // Given: Edge case - empty original
        let enhanced = EnhancedText(
            originalText: "",
            enhancedText: "",
            documentType: .unknown
        )

        // Then
        XCTAssertEqual(enhanced.improvementRatio, 0.0)
        XCTAssertEqual(enhanced.appliedRules.count, 0)
    }

    func testMultipleCloudProviders() {
        // Given: Claude enhancement
        let claudeEnhanced = EnhancedText(
            originalText: "make this professional",
            enhancedText: "Please make this professional.",
            documentType: .email,
            cloudEnhanced: true,
            cloudProvider: "Claude"
        )

        // Then
        XCTAssertEqual(claudeEnhanced.cloudProvider, "Claude")

        // Given: OpenAI enhancement
        let openaiEnhanced = EnhancedText(
            originalText: "make this professional",
            enhancedText: "Kindly make this professional.",
            documentType: .email,
            cloudEnhanced: true,
            cloudProvider: "OpenAI"
        )

        // Then
        XCTAssertEqual(openaiEnhanced.cloudProvider, "OpenAI")
    }
}
