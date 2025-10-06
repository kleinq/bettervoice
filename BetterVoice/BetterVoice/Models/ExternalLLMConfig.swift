//
//  ExternalLLMConfig.swift
//  BetterVoice
//
//  Model representing cloud LLM provider configuration
//  API keys stored in Keychain, config persisted to UserDefaults
//

import Foundation

struct ExternalLLMConfig: Codable, Identifiable {
    let id: UUID
    var provider: String
    var isEnabled: Bool
    var apiKeyKeychainItem: String
    var endpoint: URL
    var model: String
    var systemPrompts: [DocumentType: String]
    var timeoutSeconds: Int
    var maxRetries: Int
    var lastTestDate: Date?
    var lastTestStatus: Bool?

    // Default initializer
    init(
        id: UUID = UUID(),
        provider: String,
        isEnabled: Bool,
        apiKeyKeychainItem: String,
        endpoint: URL,
        model: String,
        systemPrompts: [DocumentType: String],
        timeoutSeconds: Int,
        maxRetries: Int,
        lastTestDate: Date? = nil,
        lastTestStatus: Bool? = nil
    ) {
        self.id = id
        self.provider = provider
        self.isEnabled = isEnabled
        self.apiKeyKeychainItem = apiKeyKeychainItem
        self.endpoint = endpoint
        self.model = model
        self.systemPrompts = systemPrompts
        self.timeoutSeconds = timeoutSeconds
        self.maxRetries = maxRetries
        self.lastTestDate = lastTestDate
        self.lastTestStatus = lastTestStatus
    }

    // Default system prompts per document type (FR-020)
    static let defaultSystemPrompts: [DocumentType: String] = [
        .email: "Format this transcribed speech as a professional email with proper greeting, paragraphs, and closing. Maintain professional tone while correcting grammar and removing filler words.",

        .message: "Format this transcribed speech as a casual message. Preserve informal, conversational tone but fix grammar and remove obvious filler words like 'um' and 'uh'.",

        .document: "Format this transcribed speech as structured document text with proper headings, lists, and paragraphs. Add appropriate punctuation and capitalization.",

        .searchQuery: "Convert this transcribed speech into a concise search query. Remove all filler words, keep only the essential keywords and intent.",

        .unknown: "Clean up this transcribed text by removing filler words, adding punctuation, and correcting obvious grammar errors while preserving the original meaning and tone."
    ]

    // Validation: FR-021 timeout range 5-120 seconds
    var isTimeoutValid: Bool {
        return timeoutSeconds >= 5 && timeoutSeconds <= 120
    }

    // Validation: maxRetries range 0-5
    var isRetriesValid: Bool {
        return maxRetries >= 0 && maxRetries <= 5
    }
}
