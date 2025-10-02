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

struct UserPreferences: Codable, @unchecked Sendable {
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
    var logLevel: LogLevel
    var autoDeleteTranscriptions: Bool
    var autoDeleteAfterDays: Int

    // NLP Enhancement Parameters
    var removeFillerWords: Bool
    var autoCapitalize: Bool
    var autoPunctuate: Bool
    var applyLearningPatterns: Bool

    // Onboarding
    var hasCompletedOnboarding: Bool

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
        logLevel: LogLevel = .info,
        autoDeleteTranscriptions: Bool = false,
        autoDeleteAfterDays: Int = 30,
        removeFillerWords: Bool = true,
        autoCapitalize: Bool = true,
        autoPunctuate: Bool = true,
        applyLearningPatterns: Bool = true,
        hasCompletedOnboarding: Bool = false
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
        self.logLevel = logLevel
        self.autoDeleteTranscriptions = autoDeleteTranscriptions
        self.autoDeleteAfterDays = autoDeleteAfterDays
        self.removeFillerWords = removeFillerWords
        self.autoCapitalize = autoCapitalize
        self.autoPunctuate = autoPunctuate
        self.applyLearningPatterns = applyLearningPatterns
        self.hasCompletedOnboarding = hasCompletedOnboarding
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
}
