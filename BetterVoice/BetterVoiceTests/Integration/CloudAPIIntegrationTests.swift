//
//  CloudAPIIntegrationTests.swift
//  BetterVoiceTests
//
//  Integration test for cloud API enhancement workflow
//  Tests MUST FAIL until implementation (TDD Red phase)
//

import XCTest
@testable import BetterVoice

final class CloudAPIIntegrationTests: XCTestCase {
    var appState: AppState!
    var claudeClient: ClaudeAPIClient!
    var openAIClient: OpenAIAPIClient!

    override func setUp() async throws {
        try await super.setUp()
        appState = AppState()
        claudeClient = ClaudeAPIClient()
        openAIClient = OpenAIAPIClient()
    }

    override func tearDown() async throws {
        openAIClient = nil
        claudeClient = nil
        appState = nil
        try await super.tearDown()
    }

    // MARK: - Claude API Enhancement

    func testClaudeAPIEnhancementWithMockAPI() async throws {
        // GIVEN: Claude API enabled with mock configuration
        let mockConfig = ExternalLLMConfig(
            id: UUID(),
            provider: "Claude",
            isEnabled: true,
            apiKeyKeychainItem: "test-claude-key",
            endpoint: URL(string: "https://api.anthropic.com/v1/messages")!,
            model: "claude-3-sonnet-20240229",
            systemPrompts: ExternalLLMConfig.defaultSystemPrompts,
            timeoutSeconds: 30,
            maxRetries: 2,
            lastTestDate: nil,
            lastTestStatus: nil
        )

        appState.externalLLMConfig = mockConfig
        appState.preferences.externalLLMEnabled = true

        let rawText = "hi i wanted to tell you about the meeting yesterday we discussed the project timeline"

        // WHEN: Enhancement with cloud API (mocked)
        let result = try await claudeClient.enhance(
            text: rawText,
            documentType: .email,
            systemPrompt: mockConfig.systemPrompts[.email]!
        )

        // THEN: Should return enhanced text
        XCTAssertNotEqual(result, rawText, "Should enhance text")
        XCTAssertTrue(result.count > rawText.count, "Enhanced text usually longer with formatting")
        XCTAssertTrue(result.contains("Hi") || result.contains("Dear"), "Should have proper email greeting")
    }

    // MARK: - OpenAI API Enhancement

    func testOpenAIAPIEnhancementWithMockAPI() async throws {
        // GIVEN: OpenAI API enabled with mock configuration
        let mockConfig = ExternalLLMConfig(
            id: UUID(),
            provider: "OpenAI",
            isEnabled: true,
            apiKeyKeychainItem: "test-openai-key",
            endpoint: URL(string: "https://api.openai.com/v1/chat/completions")!,
            model: "gpt-4",
            systemPrompts: ExternalLLMConfig.defaultSystemPrompts,
            timeoutSeconds: 30,
            maxRetries: 2,
            lastTestDate: nil,
            lastTestStatus: nil
        )

        appState.externalLLMConfig = mockConfig
        appState.preferences.externalLLMEnabled = true
        appState.preferences.externalLLMProvider = "OpenAI"

        let rawText = "hey can you send me the document we talked about yesterday thanks"

        // WHEN: Enhancement with OpenAI (mocked)
        let result = try await openAIClient.enhance(
            text: rawText,
            documentType: .message,
            systemPrompt: mockConfig.systemPrompts[.message]!
        )

        // THEN: Should return enhanced text
        XCTAssertNotEqual(result, rawText, "Should enhance text")
        // Messages should stay casual but be cleaned up
        XCTAssertTrue(result.lowercased().contains("hey") || result.lowercased().contains("hi"), "Should keep casual tone")
    }

    // MARK: - Fallback to Local-Only on API Failure

    func testFallbackToLocalOnCloudAPIFailure() async throws {
        // GIVEN: Invalid API configuration (will fail)
        let invalidConfig = ExternalLLMConfig(
            id: UUID(),
            provider: "Claude",
            isEnabled: true,
            apiKeyKeychainItem: "invalid-key",
            endpoint: URL(string: "https://invalid.example.com/api")!,
            model: "claude-3-sonnet-20240229",
            systemPrompts: ExternalLLMConfig.defaultSystemPrompts,
            timeoutSeconds: 1, // Short timeout to force failure
            maxRetries: 0, // No retries
            lastTestDate: nil,
            lastTestStatus: nil
        )

        appState.externalLLMConfig = invalidConfig
        appState.preferences.externalLLMEnabled = true

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

        // WHEN: Complete workflow with cloud failure
        try await appState.handleHotkeyPress()
        appState.simulateTranscription(text: "hi sarah thanks for your help")
        try await appState.handleHotkeyRelease()

        await waitForStatus(.ready, timeout: 10.0)

        // THEN: Should fall back to local enhancement
        XCTAssertNotNil(appState.currentEnhancement, "Should complete with local enhancement")
        XCTAssertFalse(appState.currentEnhancement!.usedCloudAPI, "Should mark as local-only")
        XCTAssertNil(appState.currentEnhancement!.cloudProvider, "Should not have provider")

        // But still have enhancement
        let clipboardText = NSPasteboard.general.string(forType: .string)
        XCTAssertNotNil(clipboardText, "Should have text despite cloud failure")
        XCTAssertTrue(clipboardText!.contains("Hi") || clipboardText!.contains("Dear"), "Should still format as email")
    }

    // MARK: - Timeout Handling (FR-021: 30s timeout)

    func testCloudAPITimeoutHandling() async throws {
        // GIVEN: Configuration with short timeout
        let timeoutConfig = ExternalLLMConfig(
            id: UUID(),
            provider: "Claude",
            isEnabled: true,
            apiKeyKeychainItem: "test-key",
            endpoint: URL(string: "https://slow-api.example.com")!,
            model: "claude-3-sonnet-20240229",
            systemPrompts: ExternalLLMConfig.defaultSystemPrompts,
            timeoutSeconds: 0.5, // Very short timeout
            maxRetries: 0,
            lastTestDate: nil,
            lastTestStatus: nil
        )

        let rawText = "test message"

        // WHEN: API call times out
        let startTime = Date()
        do {
            _ = try await claudeClient.enhance(
                text: rawText,
                documentType: .email,
                systemPrompt: timeoutConfig.systemPrompts[.email]!
            )
            XCTFail("Should throw timeout error")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)

            // THEN: Should timeout quickly
            XCTAssertLessThan(elapsed, 1.0, "Should timeout within configured time")
            XCTAssertTrue(error is LLMProviderError, "Should throw LLMProviderError")
        }
    }

    // MARK: - System Prompt Customization

    func testCustomSystemPromptsPerDocumentType() async throws {
        // GIVEN: Custom system prompts
        var customPrompts = ExternalLLMConfig.defaultSystemPrompts
        customPrompts[.email] = "Format as a professional business email with formal language."
        customPrompts[.message] = "Keep it super casual and friendly."

        let config = ExternalLLMConfig(
            id: UUID(),
            provider: "Claude",
            isEnabled: true,
            apiKeyKeychainItem: "test-key",
            endpoint: URL(string: "https://api.anthropic.com/v1/messages")!,
            model: "claude-3-sonnet-20240229",
            systemPrompts: customPrompts,
            timeoutSeconds: 30,
            maxRetries: 2,
            lastTestDate: nil,
            lastTestStatus: nil
        )

        // WHEN: Enhance for different document types
        let emailResult = try await claudeClient.enhance(
            text: "hi there thanks",
            documentType: .email,
            systemPrompt: config.systemPrompts[.email]!
        )

        let messageResult = try await claudeClient.enhance(
            text: "hi there thanks",
            documentType: .message,
            systemPrompt: config.systemPrompts[.message]!
        )

        // THEN: Results should reflect different prompts
        XCTAssertNotEqual(emailResult, messageResult, "Different prompts should produce different results")
        // Email should be more formal
        XCTAssertTrue(emailResult.contains("Dear") || emailResult.contains("Sincerely"), "Email should be formal")
        // Message should be casual
        XCTAssertTrue(messageResult.contains("hey") || messageResult.contains("hi"), "Message should be casual")
    }

    // MARK: - Cloud Enhancement Metadata Tracking

    func testCloudEnhancementMetadataTracking() async throws {
        // GIVEN: Cloud API enabled
        let config = ExternalLLMConfig(
            id: UUID(),
            provider: "Claude",
            isEnabled: true,
            apiKeyKeychainItem: "test-key",
            endpoint: URL(string: "https://api.anthropic.com/v1/messages")!,
            model: "claude-3-sonnet-20240229",
            systemPrompts: ExternalLLMConfig.defaultSystemPrompts,
            timeoutSeconds: 30,
            maxRetries: 2,
            lastTestDate: nil,
            lastTestStatus: nil
        )

        appState.externalLLMConfig = config
        appState.preferences.externalLLMEnabled = true

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

        // WHEN: Complete workflow with cloud enhancement
        try await appState.handleHotkeyPress()
        appState.simulateTranscription(text: "test message")
        try await appState.handleHotkeyRelease()

        await waitForStatus(.ready, timeout: 10.0)

        // THEN: Enhancement should track cloud usage
        XCTAssertNotNil(appState.currentEnhancement, "Should have enhancement")
        XCTAssertTrue(appState.currentEnhancement!.usedCloudAPI, "Should mark as cloud-enhanced")
        XCTAssertEqual(appState.currentEnhancement!.cloudProvider, "Claude", "Should track provider")
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

        XCTFail("Timeout waiting for status \(expectedStatus)")
    }
}

// MARK: - Supporting Types

enum LLMProviderError: Error {
    case timeout
    case invalidResponse
    case apiError(String)
}
