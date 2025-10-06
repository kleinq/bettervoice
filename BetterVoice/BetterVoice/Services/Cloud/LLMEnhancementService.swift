//
//  LLMEnhancementService.swift
//  BetterVoice
//
//  Coordinates cloud LLM enhancement with fallback to local-only
//  Loads API keys from Keychain, selects provider from UserPreferences
//

import Foundation

final class LLMEnhancementService {

    // MARK: - Singleton

    static let shared = LLMEnhancementService()
    private init() {}

    // MARK: - Dependencies

    private let keychainHelper = KeychainHelper.shared
    private let preferencesStore = PreferencesStore.shared

    // MARK: - Public Methods

    /// Enhance text using configured cloud LLM provider
    func enhance(
        text: String,
        documentType: DocumentType,
        customPrompt: String? = nil
    ) async throws -> String {
        // Get user preferences
        let preferences = preferencesStore.preferences

        // Check if cloud enhancement is enabled
        guard preferences.externalLLMEnabled else {
            throw LLMEnhancementError.cloudDisabled
        }

        // Get the configured provider
        guard let provider = getConfiguredProvider() else {
            throw LLMEnhancementError.noProviderConfigured
        }

        do {
            // Attempt cloud enhancement
            let enhanced = try await provider.enhance(
                text: text,
                documentType: documentType,
                systemPrompt: customPrompt
            )

            Logger.shared.info("Cloud LLM enhancement successful")
            return enhanced

        } catch {
            Logger.shared.error("Cloud LLM enhancement failed", error: error)
            throw LLMEnhancementError.enhancementFailed(error)
        }
    }

    /// Check if cloud enhancement is available
    func isAvailable() -> Bool {
        let preferences = preferencesStore.preferences
        return preferences.externalLLMEnabled && getConfiguredProvider() != nil
    }

    /// Get the name of the configured provider
    func getProviderName() -> String? {
        let preferences = preferencesStore.preferences

        if let provider = preferences.externalLLMProvider {
            return provider.capitalized
        }

        return nil
    }

    // MARK: - Private Methods

    private func getConfiguredProvider() -> LLMProvider? {
        let preferences = preferencesStore.preferences

        guard let provider = preferences.externalLLMProvider else {
            return nil
        }

        let providerLower = provider.lowercased()

        // Try to get API key from keychain
        guard let apiKey = try? keychainHelper.retrieveAPIKey(provider: providerLower), !apiKey.isEmpty else {
            return nil
        }

        // Create provider client based on type
        switch providerLower {
        case "claude":
            return ClaudeAPIClient(
                apiKey: apiKey,
                model: "claude-3-5-sonnet-20241022",
                timeout: 30.0
            )
        case "openai":
            return OpenAIAPIClient(
                apiKey: apiKey,
                model: "gpt-4",
                timeout: 30.0
            )
        default:
            return nil
        }
    }
}

// MARK: - Error Types

enum LLMEnhancementError: Error {
    case cloudDisabled
    case noProviderConfigured
    case enhancementFailed(Error)
}
