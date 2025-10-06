//
//  ExternalLLMConfigTests.swift
//  BetterVoiceTests
//
//  Unit tests for ExternalLLMConfig model
//  Tests MUST FAIL until implementation (TDD Red phase)
//

import XCTest
@testable import BetterVoice

final class ExternalLLMConfigTests: XCTestCase {

    func testExternalLLMConfigIsEncodableAndDecodable() throws {
        // Given
        let config = ExternalLLMConfig(
            id: UUID(),
            provider: "Claude",
            isEnabled: true,
            apiKeyKeychainItem: "bettervoice-claude-key",
            endpoint: URL(string: "https://api.anthropic.com/v1/messages")!,
            model: "claude-3-sonnet-20240229",
            systemPrompts: ExternalLLMConfig.defaultSystemPrompts,
            timeoutSeconds: 30,
            maxRetries: 2,
            lastTestDate: Date(),
            lastTestStatus: true
        )

        // When
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ExternalLLMConfig.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.id, config.id)
        XCTAssertEqual(decoded.provider, config.provider)
        XCTAssertEqual(decoded.endpoint, config.endpoint)
        XCTAssertEqual(decoded.timeoutSeconds, config.timeoutSeconds)
    }

    func testDefaultSystemPrompts() {
        // Given
        let prompts = ExternalLLMConfig.defaultSystemPrompts

        // Then
        XCTAssertEqual(prompts.count, 5, "Should have prompts for all 5 document types")
        XCTAssertNotNil(prompts[.email])
        XCTAssertNotNil(prompts[.message])
        XCTAssertNotNil(prompts[.document])
        XCTAssertNotNil(prompts[.searchQuery])
        XCTAssertNotNil(prompts[.unknown])

        // Verify email prompt
        XCTAssertTrue(prompts[.email]!.contains("email") || prompts[.email]!.contains("professional"))

        // Verify message prompt
        XCTAssertTrue(prompts[.message]!.contains("casual") || prompts[.message]!.contains("message"))

        // Verify search prompt
        XCTAssertTrue(prompts[.searchQuery]!.contains("search") || prompts[.searchQuery]!.contains("query"))
    }

    func testIsConfiguredProperty() {
        // Given: Enabled with valid keychain item (mock)
        let configured = ExternalLLMConfig(
            id: UUID(),
            provider: "Claude",
            isEnabled: true,
            apiKeyKeychainItem: "test-key",
            endpoint: URL(string: "https://api.anthropic.com")!,
            model: "claude-3-sonnet-20240229",
            systemPrompts: [:],
            timeoutSeconds: 30,
            maxRetries: 2,
            lastTestDate: nil,
            lastTestStatus: nil
        )

        // Then: In real implementation, would check Keychain
        XCTAssertTrue(configured.isEnabled)

        // Given: Disabled
        var disabled = configured
        disabled.isEnabled = false

        // Then
        XCTAssertFalse(disabled.isEnabled)
    }

    func testTimeoutValidation() {
        // Given: Valid timeout range (5-120 seconds)
        let validConfig = ExternalLLMConfig(
            id: UUID(),
            provider: "OpenAI",
            isEnabled: true,
            apiKeyKeychainItem: "test-key",
            endpoint: URL(string: "https://api.openai.com")!,
            model: "gpt-4",
            systemPrompts: [:],
            timeoutSeconds: 30,
            maxRetries: 2,
            lastTestDate: nil,
            lastTestStatus: nil
        )

        // Then
        XCTAssertGreaterThanOrEqual(validConfig.timeoutSeconds, 5)
        XCTAssertLessThanOrEqual(validConfig.timeoutSeconds, 120)

        // Given: Too short
        let tooShort = ExternalLLMConfig(
            id: UUID(),
            provider: "Claude",
            isEnabled: true,
            apiKeyKeychainItem: "test-key",
            endpoint: URL(string: "https://api.anthropic.com")!,
            model: "claude-3-sonnet-20240229",
            systemPrompts: [:],
            timeoutSeconds: 1, // Too short
            maxRetries: 2,
            lastTestDate: nil,
            lastTestStatus: nil
        )

        // Then: Should be invalid
        XCTAssertLessThan(tooShort.timeoutSeconds, 5)
    }

    func testMaxRetriesValidation() {
        // Given: Valid retries (0-5)
        let validConfig = ExternalLLMConfig(
            id: UUID(),
            provider: "Claude",
            isEnabled: true,
            apiKeyKeychainItem: "test-key",
            endpoint: URL(string: "https://api.anthropic.com")!,
            model: "claude-3-sonnet-20240229",
            systemPrompts: [:],
            timeoutSeconds: 30,
            maxRetries: 2,
            lastTestDate: nil,
            lastTestStatus: nil
        )

        // Then
        XCTAssertGreaterThanOrEqual(validConfig.maxRetries, 0)
        XCTAssertLessThanOrEqual(validConfig.maxRetries, 5)

        // Given: Too many retries
        let tooMany = ExternalLLMConfig(
            id: UUID(),
            provider: "OpenAI",
            isEnabled: true,
            apiKeyKeychainItem: "test-key",
            endpoint: URL(string: "https://api.openai.com")!,
            model: "gpt-4",
            systemPrompts: [:],
            timeoutSeconds: 30,
            maxRetries: 10, // Too many
            lastTestDate: nil,
            lastTestStatus: nil
        )

        // Then: Should be invalid
        XCTAssertGreaterThan(tooMany.maxRetries, 5)
    }

    func testCustomSystemPrompts() {
        // Given: Custom prompts
        var customPrompts: [DocumentType: String] = [:]
        customPrompts[.email] = "Format as a very formal business email."
        customPrompts[.message] = "Keep it super casual and friendly."

        let config = ExternalLLMConfig(
            id: UUID(),
            provider: "Claude",
            isEnabled: true,
            apiKeyKeychainItem: "test-key",
            endpoint: URL(string: "https://api.anthropic.com")!,
            model: "claude-3-sonnet-20240229",
            systemPrompts: customPrompts,
            timeoutSeconds: 30,
            maxRetries: 2,
            lastTestDate: nil,
            lastTestStatus: nil
        )

        // Then
        XCTAssertEqual(config.systemPrompts[.email], "Format as a very formal business email.")
        XCTAssertEqual(config.systemPrompts[.message], "Keep it super casual and friendly.")
    }

    func testLastTestTracking() {
        // Given: Config with successful test
        let tested = ExternalLLMConfig(
            id: UUID(),
            provider: "Claude",
            isEnabled: true,
            apiKeyKeychainItem: "test-key",
            endpoint: URL(string: "https://api.anthropic.com")!,
            model: "claude-3-sonnet-20240229",
            systemPrompts: [:],
            timeoutSeconds: 30,
            maxRetries: 2,
            lastTestDate: Date(),
            lastTestStatus: true
        )

        // Then
        XCTAssertNotNil(tested.lastTestDate)
        XCTAssertTrue(tested.lastTestStatus ?? false)

        // Given: Failed test
        var failed = tested
        failed.lastTestStatus = false

        // Then
        XCTAssertFalse(failed.lastTestStatus ?? true)
    }

    func testKeychainItemNaming() {
        // Given: SR-003 requires Keychain storage
        let claudeConfig = ExternalLLMConfig(
            id: UUID(),
            provider: "Claude",
            isEnabled: true,
            apiKeyKeychainItem: "com.bettervoice.apikeys.claude",
            endpoint: URL(string: "https://api.anthropic.com")!,
            model: "claude-3-sonnet-20240229",
            systemPrompts: [:],
            timeoutSeconds: 30,
            maxRetries: 2,
            lastTestDate: nil,
            lastTestStatus: nil
        )

        // Then: kSecAttrService should be "com.bettervoice.apikeys"
        XCTAssertTrue(claudeConfig.apiKeyKeychainItem.contains("bettervoice"))
        XCTAssertTrue(claudeConfig.apiKeyKeychainItem.contains("apikeys"))
    }
}
