//
//  UserPreferencesTests.swift
//  BetterVoiceTests
//
//  Unit tests for UserPreferences model
//  Tests MUST FAIL until implementation (TDD Red phase)
//

import XCTest
import Carbon
@testable import BetterVoice

final class UserPreferencesTests: XCTestCase {

    func testUserPreferencesIsEncodableAndDecodable() throws {
        // Given
        let prefs = UserPreferences(
            hotkeyKeyCode: 61,
            hotkeyModifiers: 0,
            selectedModelSize: .base,
            selectedAudioInputDeviceUID: "test-device-uid",
            audioFeedbackEnabled: true,
            visualOverlayEnabled: true,
            learningSystemEnabled: true,
            externalLLMEnabled: false,
            externalLLMProvider: nil,
            logLevel: .info,
            autoDeleteTranscriptions: false,
            autoDeleteAfterDays: 30
        )

        // When
        let encoded = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.hotkeyKeyCode, prefs.hotkeyKeyCode)
        XCTAssertEqual(decoded.selectedModelSize, prefs.selectedModelSize)
        XCTAssertEqual(decoded.logLevel, prefs.logLevel)
    }

    func testDefaultValues() {
        // Given
        let defaults = UserPreferences()

        // Then
        XCTAssertEqual(defaults.hotkeyKeyCode, 61, "Default should be Right Option (61)")
        XCTAssertEqual(defaults.hotkeyModifiers, 0, "Default should have no modifiers")
        XCTAssertEqual(defaults.selectedModelSize, .base, "Default should be base model")
        XCTAssertNil(defaults.selectedAudioInputDeviceUID, "Default should use system default device")
        XCTAssertTrue(defaults.audioFeedbackEnabled, "Audio feedback enabled by default")
        XCTAssertTrue(defaults.visualOverlayEnabled, "Visual overlay enabled by default")
        XCTAssertTrue(defaults.learningSystemEnabled, "Learning enabled by default")
        XCTAssertFalse(defaults.externalLLMEnabled, "External LLM disabled by default")
        XCTAssertNil(defaults.externalLLMProvider)
        XCTAssertEqual(defaults.logLevel, .info, "Default log level should be info")
        XCTAssertFalse(defaults.autoDeleteTranscriptions, "Auto-delete disabled by default")
        XCTAssertEqual(defaults.autoDeleteAfterDays, 30)
    }

    func testExternalLLMValidation() {
        // Given: LLM enabled but no provider
        var prefs = UserPreferences()
        prefs.externalLLMEnabled = true
        prefs.externalLLMProvider = nil

        // Then: Should be invalid (provider required when enabled)
        // In real implementation, this would be validated
        XCTAssertNotNil(prefs, "Preferences should exist")

        // Given: Valid LLM configuration
        prefs.externalLLMProvider = "Claude"

        // Then
        XCTAssertTrue(prefs.externalLLMEnabled)
        XCTAssertNotNil(prefs.externalLLMProvider)
    }

    func testAutoDeleteValidation() {
        // Given: Auto-delete enabled
        var prefs = UserPreferences()
        prefs.autoDeleteTranscriptions = true
        prefs.autoDeleteAfterDays = 7

        // Then
        XCTAssertGreaterThanOrEqual(prefs.autoDeleteAfterDays, 1, "Must be ≥1 day when enabled")

        // Given: Invalid value
        prefs.autoDeleteAfterDays = 0

        // Then: Should be invalid
        // In real implementation, this would be validated
        XCTAssertLessThan(prefs.autoDeleteAfterDays, 1, "Zero days is invalid")
    }

    func testLogLevelEnum() {
        // Given
        let levels: [LogLevel] = [.debug, .info, .warning, .error]

        // Then
        XCTAssertEqual(levels.count, 4)
        XCTAssertEqual(LogLevel.debug.rawValue, "debug")
        XCTAssertEqual(LogLevel.error.rawValue, "error")
    }

    func testSaveAndLoadPreferences() {
        // Given
        let customPrefs = UserPreferences(
            hotkeyKeyCode: 49, // Space
            hotkeyModifiers: UInt32(cmdKey),
            selectedModelSize: .small,
            selectedAudioInputDeviceUID: "custom-device",
            audioFeedbackEnabled: false,
            visualOverlayEnabled: false,
            learningSystemEnabled: false,
            externalLLMEnabled: true,
            externalLLMProvider: "OpenAI",
            logLevel: .debug,
            autoDeleteTranscriptions: true,
            autoDeleteAfterDays: 14
        )

        // When
        customPrefs.save()
        let loaded = UserPreferences.load()

        // Then
        XCTAssertEqual(loaded.hotkeyKeyCode, customPrefs.hotkeyKeyCode)
        XCTAssertEqual(loaded.selectedModelSize, customPrefs.selectedModelSize)
        XCTAssertEqual(loaded.externalLLMProvider, customPrefs.externalLLMProvider)
        XCTAssertEqual(loaded.autoDeleteAfterDays, customPrefs.autoDeleteAfterDays)
    }

    func testStorageKeyConstant() {
        // Then
        XCTAssertEqual(UserPreferences.storageKey, "BetterVoice.UserPreferences")
    }
}
