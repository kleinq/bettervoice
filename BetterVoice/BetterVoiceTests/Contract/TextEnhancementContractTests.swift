//
//  TextEnhancementContractTests.swift
//  BetterVoiceTests
//
//  Contract tests for TextEnhancementService
//  Tests MUST FAIL until implementation (TDD Red phase)
//

import XCTest
@testable import BetterVoice

final class TextEnhancementContractTests: XCTestCase {
    var sut: TextEnhancementService!

    override func setUp() {
        super.setUp()
        sut = TextEnhancementService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Contract: Removes filler words

    func testEnhanceRemovesFillerWords() async throws {
        // Given
        let textWithFillers = "um hi there uh I wanted to uh you know tell you that um basically I think this is you know actually pretty good"
        let context = DocumentTypeContext(
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

        // When
        let result = try await sut.enhance(
            text: textWithFillers,
            documentType: context.detectedType,
            applyLearning: false,
            useCloud: false
        )

        // Then
        XCTAssertFalse(result.enhancedText.contains("um"), "Should remove 'um'")
        XCTAssertFalse(result.enhancedText.contains("uh"), "Should remove 'uh'")
        XCTAssertFalse(result.enhancedText.contains("you know"), "Should remove 'you know'")
        XCTAssertFalse(result.enhancedText.contains("basically"), "Should remove 'basically'")
        XCTAssertFalse(result.enhancedText.contains("actually"), "Should remove 'actually'")
        XCTAssertGreaterThan(result.removedFillers.count, 0, "Should track removed fillers")
    }

    // MARK: - Contract: Formats by document type

    func testEnhanceFormatsEmailCorrectly() async throws {
        // Given
        let rawText = "hi sarah i wanted to follow up on our meeting yesterday thanks"

        // When
        let result = try await sut.enhance(
            text: rawText,
            documentType: .email,
            applyLearning: false,
            useCloud: false
        )

        // Then
        XCTAssertTrue(result.enhancedText.contains("Hi"), "Should capitalize greeting")
        XCTAssertTrue(result.enhancedText.contains("Sarah"), "Should capitalize name")
        XCTAssertTrue(result.enhancedText.contains(","), "Should add punctuation")
        XCTAssertTrue(result.enhancedText.contains("."), "Should add periods")
        XCTAssertTrue(result.enhancedText.contains("\n"), "Should have paragraphs")
    }

    func testEnhanceFormatsMessageCorrectly() async throws {
        // Given
        let rawText = "hey can you send me the link for that thing we talked about"

        // When
        let result = try await sut.enhance(
            text: rawText,
            documentType: .message,
            applyLearning: false,
            useCloud: false
        )

        // Then
        XCTAssertTrue(result.enhancedText.hasPrefix("Hey"), "Should capitalize first word")
        XCTAssertTrue(result.enhancedText.hasSuffix("?") || result.enhancedText.hasSuffix("."), "Should end with punctuation")
        // Messages should be more casual, less formatting
        let paragraphCount = result.enhancedText.components(separatedBy: "\n\n").count
        XCTAssertLessThan(paragraphCount, 3, "Messages should have minimal paragraphs")
    }

    func testEnhanceFormatsSearchQueryCorrectly() async throws {
        // Given
        let rawText = "um i want to find uh restaurants near me that are open now"

        // When
        let result = try await sut.enhance(
            text: rawText,
            documentType: .searchQuery,
            applyLearning: false,
            useCloud: false
        )

        // Then
        XCTAssertFalse(result.enhancedText.contains("um"), "Should remove fillers")
        XCTAssertFalse(result.enhancedText.contains("uh"), "Should remove fillers")
        XCTAssertLessThan(result.enhancedText.count, rawText.count, "Search should be concise")
        XCTAssertTrue(result.enhancedText.lowercased().contains("restaurants"), "Should preserve key terms")
        XCTAssertTrue(result.enhancedText.lowercased().contains("open"), "Should preserve key terms")
    }

    // MARK: - Contract: Applies learning patterns

    func testEnhanceAppliesLearningPatterns() async throws {
        // Given
        let rawText = "thanks for your help"
        let patterns = [
            LearningPattern(
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
        ]

        // When
        let result = try await sut.enhance(
            text: rawText,
            documentType: .email,
            applyLearning: true,
            useCloud: false,
            learningPatterns: patterns
        )

        // Then
        XCTAssertTrue(result.enhancedText.contains("thank you"), "Should apply learned pattern")
        XCTAssertGreaterThan(result.learningPatternsApplied, 0, "Should track applied patterns")
    }

    // MARK: - Contract: Cloud API enhancement with fallback

    func testEnhanceUsesCloudAPIWhenEnabled() async throws {
        // Given
        let rawText = "hi i wanted to tell you about the project status"
        let mockLLMConfig = ExternalLLMConfig(
            id: UUID(),
            provider: "Claude",
            isEnabled: true,
            apiKeyKeychainItem: "test-key",
            endpoint: URL(string: "https://api.anthropic.com/v1/messages")!,
            model: "claude-3-sonnet-20240229",
            systemPrompts: [:],
            timeoutSeconds: 30,
            maxRetries: 2,
            lastTestDate: nil,
            lastTestStatus: nil
        )

        // When
        let result = try await sut.enhance(
            text: rawText,
            documentType: .email,
            applyLearning: false,
            useCloud: true,
            llmConfig: mockLLMConfig
        )

        // Then
        XCTAssertTrue(result.usedCloudAPI, "Should use cloud API when enabled")
        XCTAssertEqual(result.cloudProvider, "Claude", "Should track provider")
        XCTAssertNotEqual(result.enhancedText, rawText, "Should enhance text")
    }

    func testEnhanceFallsBackToLocalOnCloudFailure() async throws {
        // Given
        let rawText = "hi sarah thanks for your help"
        let invalidConfig = ExternalLLMConfig(
            id: UUID(),
            provider: "Claude",
            isEnabled: true,
            apiKeyKeychainItem: "invalid-key",
            endpoint: URL(string: "https://invalid.example.com")!,
            model: "claude-3-sonnet-20240229",
            systemPrompts: [:],
            timeoutSeconds: 1, // Short timeout to force failure
            maxRetries: 0,
            lastTestDate: nil,
            lastTestStatus: nil
        )

        // When
        let result = try await sut.enhance(
            text: rawText,
            documentType: .email,
            applyLearning: false,
            useCloud: true,
            llmConfig: invalidConfig
        )

        // Then
        XCTAssertFalse(result.usedCloudAPI, "Should fall back to local when cloud fails")
        XCTAssertNil(result.cloudProvider, "Should not track provider on failure")
        XCTAssertNotEqual(result.enhancedText, rawText, "Should still enhance locally")
    }
}

// MARK: - Supporting Types (Contracts)

protocol TextEnhancementServiceProtocol {
    func enhance(
        text: String,
        documentType: DocumentType,
        applyLearning: Bool,
        useCloud: Bool,
        learningPatterns: [LearningPattern]?,
        llmConfig: ExternalLLMConfig?
    ) async throws -> EnhancedText
}
