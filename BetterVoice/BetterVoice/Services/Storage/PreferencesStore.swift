//
//  PreferencesStore.swift
//  BetterVoice
//
//  UserDefaults wrapper for user preferences
//  Provides type-safe access to app settings
//

import Foundation
import Combine

final class PreferencesStore: ObservableObject {
    static let shared = PreferencesStore()

    private let userDefaults: UserDefaults

    // Keys
    private enum Keys {
        static let userPreferences = "BetterVoice.UserPreferences"
        static let hasCompletedOnboarding = "BetterVoice.HasCompletedOnboarding"
        static let lastModelDownloadCheck = "BetterVoice.LastModelDownloadCheck"
    }

    // Private init for singleton
    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - User Preferences

    @Published var preferences: UserPreferences = UserPreferences.load()

    func savePreferences(_ newPreferences: UserPreferences) {
        preferences = newPreferences
        newPreferences.save()
    }

    // MARK: - Onboarding

    var hasCompletedOnboarding: Bool {
        get {
            userDefaults.bool(forKey: Keys.hasCompletedOnboarding)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.hasCompletedOnboarding)
        }
    }

    // MARK: - Model Management

    var lastModelDownloadCheck: Date? {
        get {
            userDefaults.object(forKey: Keys.lastModelDownloadCheck) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: Keys.lastModelDownloadCheck)
        }
    }

    // MARK: - Helpers

    func reset() {
        userDefaults.removeObject(forKey: Keys.userPreferences)
        userDefaults.removeObject(forKey: Keys.hasCompletedOnboarding)
        userDefaults.removeObject(forKey: Keys.lastModelDownloadCheck)
    }

    func synchronize() {
        userDefaults.synchronize()
    }
}
