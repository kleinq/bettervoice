//
//  UserPreferences.swift
//  BetterVoice
//
//  Model representing user preferences and settings
//  Persisted to UserDefaults via Codable
//

import Foundation
import Carbon

enum LogLevel: String, Codable {
    case debug
    case info
    case warning
    case error
}

struct UserPreferences: @unchecked Sendable {
    var hotkeyKeyCode: UInt32
    var hotkeyModifiers: UInt32
    var selectedModelSize: WhisperModelSize
    var selectedAudioInputDeviceUID: String?
    var audioFeedbackEnabled: Bool
    var recordingStartSound: String
    var recordingStopSound: String
    var processingCompleteSound: String
    var errorSound: String
    var pasteSound: String
    var visualOverlayEnabled: Bool
    var learningSystemEnabled: Bool
    var externalLLMEnabled: Bool
    var externalLLMProvider: String?
    var externalLLMAPIKey: String?
    var llmEnhanceEmail: Bool
    var llmEnhanceMessage: Bool
    var llmEnhanceDocument: Bool
    var llmEnhanceSocial: Bool
    var llmEnhanceCode: Bool
    var logLevel: LogLevel
    var autoDeleteTranscriptions: Bool
    var autoDeleteAfterDays: Int

    // NLP Enhancement Parameters
    var removeFillerWords: Bool
    var autoCapitalize: Bool
    var autoPunctuate: Bool
    var applyLearningPatterns: Bool
    var customVocabulary: [String]

    // Onboarding
    var hasCompletedOnboarding: Bool

    // Custom LLM Prompts (Feature 004-allow-editing-of)
    var customPrompts: [String: String]

    // UserDefaults storage key
    static let storageKey = "BetterVoice.UserPreferences"

    // Default initializer with FR-002 defaults
    init(
        hotkeyKeyCode: UInt32 = 15, // Cmd+R (R key = 15)
        hotkeyModifiers: UInt32 = UInt32(cmdKey), // Command key modifier
        selectedModelSize: WhisperModelSize = .base,
        selectedAudioInputDeviceUID: String? = nil,
        audioFeedbackEnabled: Bool = true,
        recordingStartSound: String = "Ping",
        recordingStopSound: String = "Pop",
        processingCompleteSound: String = "Glass",
        errorSound: String = "Basso",
        pasteSound: String = "Morse",
        visualOverlayEnabled: Bool = true,
        learningSystemEnabled: Bool = true,
        externalLLMEnabled: Bool = false,
        externalLLMProvider: String? = nil,
        externalLLMAPIKey: String? = nil,
        llmEnhanceEmail: Bool = false,
        llmEnhanceMessage: Bool = false,
        llmEnhanceDocument: Bool = false,
        llmEnhanceSocial: Bool = false,
        llmEnhanceCode: Bool = false,
        logLevel: LogLevel = .info,
        autoDeleteTranscriptions: Bool = false,
        autoDeleteAfterDays: Int = 30,
        removeFillerWords: Bool = true,
        autoCapitalize: Bool = true,
        autoPunctuate: Bool = true,
        applyLearningPatterns: Bool = true,
        customVocabulary: [String] = [],
        hasCompletedOnboarding: Bool = false,
        customPrompts: [String: String] = [:]
    ) {
        self.hotkeyKeyCode = hotkeyKeyCode
        self.hotkeyModifiers = hotkeyModifiers
        self.selectedModelSize = selectedModelSize
        self.selectedAudioInputDeviceUID = selectedAudioInputDeviceUID
        self.audioFeedbackEnabled = audioFeedbackEnabled
        self.recordingStartSound = recordingStartSound
        self.recordingStopSound = recordingStopSound
        self.processingCompleteSound = processingCompleteSound
        self.errorSound = errorSound
        self.pasteSound = pasteSound
        self.visualOverlayEnabled = visualOverlayEnabled
        self.learningSystemEnabled = learningSystemEnabled
        self.externalLLMEnabled = externalLLMEnabled
        self.externalLLMProvider = externalLLMProvider
        self.externalLLMAPIKey = externalLLMAPIKey
        self.llmEnhanceEmail = llmEnhanceEmail
        self.llmEnhanceMessage = llmEnhanceMessage
        self.llmEnhanceDocument = llmEnhanceDocument
        self.llmEnhanceSocial = llmEnhanceSocial
        self.llmEnhanceCode = llmEnhanceCode
        self.logLevel = logLevel
        self.autoDeleteTranscriptions = autoDeleteTranscriptions
        self.autoDeleteAfterDays = autoDeleteAfterDays
        self.removeFillerWords = removeFillerWords
        self.autoCapitalize = autoCapitalize
        self.autoPunctuate = autoPunctuate
        self.applyLearningPatterns = applyLearningPatterns
        self.customVocabulary = customVocabulary
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.customPrompts = customPrompts
    }

    // Save to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        }
    }

    // Load from UserDefaults
    static func load() -> UserPreferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return UserPreferences() // Return defaults if not found
        }
        return decoded
    }

    // MARK: - Custom Prompt Helpers (Feature 004-allow-editing-of)

    /// Get custom prompt for a document type, returns nil if not set or empty
    func getCustomPrompt(for documentType: DocumentType) -> String? {
        let key = documentType.rawValue
        guard let prompt = customPrompts[key],
              !prompt.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }
        return prompt
    }

    /// Set custom prompt for a document type, nil or empty string removes customization
    mutating func setCustomPrompt(_ prompt: String?, for documentType: DocumentType) {
        let key = documentType.rawValue
        if let prompt = prompt, !prompt.trimmingCharacters(in: .whitespaces).isEmpty {
            customPrompts[key] = prompt
        } else {
            customPrompts[key] = nil
        }
    }

    /// Reset prompt for a specific document type to default
    mutating func resetPrompt(for documentType: DocumentType) {
        customPrompts[documentType.rawValue] = nil
    }

    /// Reset all prompts to defaults
    mutating func resetAllPrompts() {
        customPrompts = [:]
    }
}

// MARK: - Codable Implementation with Backward Compatibility

extension UserPreferences: Codable {
    enum CodingKeys: String, CodingKey {
        case hotkeyKeyCode, hotkeyModifiers, selectedModelSize
        case selectedAudioInputDeviceUID, audioFeedbackEnabled
        case recordingStartSound, recordingStopSound, processingCompleteSound
        case errorSound, pasteSound, visualOverlayEnabled
        case learningSystemEnabled, externalLLMEnabled, externalLLMProvider
        case externalLLMAPIKey, llmEnhanceEmail, llmEnhanceMessage
        case llmEnhanceDocument, llmEnhanceSocial, llmEnhanceCode
        case logLevel, autoDeleteTranscriptions, autoDeleteAfterDays
        case removeFillerWords, autoCapitalize, autoPunctuate
        case applyLearningPatterns, customVocabulary, hasCompletedOnboarding
        case customPrompts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        hotkeyKeyCode = try container.decode(UInt32.self, forKey: .hotkeyKeyCode)
        hotkeyModifiers = try container.decode(UInt32.self, forKey: .hotkeyModifiers)
        selectedModelSize = try container.decode(WhisperModelSize.self, forKey: .selectedModelSize)
        selectedAudioInputDeviceUID = try container.decodeIfPresent(String.self, forKey: .selectedAudioInputDeviceUID)
        audioFeedbackEnabled = try container.decode(Bool.self, forKey: .audioFeedbackEnabled)
        recordingStartSound = try container.decode(String.self, forKey: .recordingStartSound)
        recordingStopSound = try container.decode(String.self, forKey: .recordingStopSound)
        processingCompleteSound = try container.decode(String.self, forKey: .processingCompleteSound)
        errorSound = try container.decode(String.self, forKey: .errorSound)
        pasteSound = try container.decode(String.self, forKey: .pasteSound)
        visualOverlayEnabled = try container.decode(Bool.self, forKey: .visualOverlayEnabled)
        learningSystemEnabled = try container.decode(Bool.self, forKey: .learningSystemEnabled)
        externalLLMEnabled = try container.decode(Bool.self, forKey: .externalLLMEnabled)
        externalLLMProvider = try container.decodeIfPresent(String.self, forKey: .externalLLMProvider)
        externalLLMAPIKey = try container.decodeIfPresent(String.self, forKey: .externalLLMAPIKey)
        llmEnhanceEmail = try container.decode(Bool.self, forKey: .llmEnhanceEmail)
        llmEnhanceMessage = try container.decode(Bool.self, forKey: .llmEnhanceMessage)
        llmEnhanceDocument = try container.decode(Bool.self, forKey: .llmEnhanceDocument)
        llmEnhanceSocial = try container.decode(Bool.self, forKey: .llmEnhanceSocial)
        llmEnhanceCode = try container.decode(Bool.self, forKey: .llmEnhanceCode)
        logLevel = try container.decode(LogLevel.self, forKey: .logLevel)
        autoDeleteTranscriptions = try container.decode(Bool.self, forKey: .autoDeleteTranscriptions)
        autoDeleteAfterDays = try container.decode(Int.self, forKey: .autoDeleteAfterDays)
        removeFillerWords = try container.decode(Bool.self, forKey: .removeFillerWords)
        autoCapitalize = try container.decode(Bool.self, forKey: .autoCapitalize)
        autoPunctuate = try container.decode(Bool.self, forKey: .autoPunctuate)
        applyLearningPatterns = try container.decode(Bool.self, forKey: .applyLearningPatterns)
        customVocabulary = try container.decode([String].self, forKey: .customVocabulary)
        hasCompletedOnboarding = try container.decode(Bool.self, forKey: .hasCompletedOnboarding)

        // NEW: Decode customPrompts with default value for backward compatibility
        customPrompts = try container.decodeIfPresent([String: String].self, forKey: .customPrompts) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(hotkeyKeyCode, forKey: .hotkeyKeyCode)
        try container.encode(hotkeyModifiers, forKey: .hotkeyModifiers)
        try container.encode(selectedModelSize, forKey: .selectedModelSize)
        try container.encodeIfPresent(selectedAudioInputDeviceUID, forKey: .selectedAudioInputDeviceUID)
        try container.encode(audioFeedbackEnabled, forKey: .audioFeedbackEnabled)
        try container.encode(recordingStartSound, forKey: .recordingStartSound)
        try container.encode(recordingStopSound, forKey: .recordingStopSound)
        try container.encode(processingCompleteSound, forKey: .processingCompleteSound)
        try container.encode(errorSound, forKey: .errorSound)
        try container.encode(pasteSound, forKey: .pasteSound)
        try container.encode(visualOverlayEnabled, forKey: .visualOverlayEnabled)
        try container.encode(learningSystemEnabled, forKey: .learningSystemEnabled)
        try container.encode(externalLLMEnabled, forKey: .externalLLMEnabled)
        try container.encodeIfPresent(externalLLMProvider, forKey: .externalLLMProvider)
        try container.encodeIfPresent(externalLLMAPIKey, forKey: .externalLLMAPIKey)
        try container.encode(llmEnhanceEmail, forKey: .llmEnhanceEmail)
        try container.encode(llmEnhanceMessage, forKey: .llmEnhanceMessage)
        try container.encode(llmEnhanceDocument, forKey: .llmEnhanceDocument)
        try container.encode(llmEnhanceSocial, forKey: .llmEnhanceSocial)
        try container.encode(llmEnhanceCode, forKey: .llmEnhanceCode)
        try container.encode(logLevel, forKey: .logLevel)
        try container.encode(autoDeleteTranscriptions, forKey: .autoDeleteTranscriptions)
        try container.encode(autoDeleteAfterDays, forKey: .autoDeleteAfterDays)
        try container.encode(removeFillerWords, forKey: .removeFillerWords)
        try container.encode(autoCapitalize, forKey: .autoCapitalize)
        try container.encode(autoPunctuate, forKey: .autoPunctuate)
        try container.encode(applyLearningPatterns, forKey: .applyLearningPatterns)
        try container.encode(customVocabulary, forKey: .customVocabulary)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(customPrompts, forKey: .customPrompts)
    }
}
