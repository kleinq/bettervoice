//
//  SoundPlayer.swift
//  BetterVoice
//
//  Play system sounds for audio feedback
//  Uses macOS built-in sounds instead of custom files
//

import Foundation
import AppKit

enum SystemSoundEvent {
    case recordingStart
    case recordingStop
    case processingComplete
    case error
    case paste
}

final class SoundPlayer {

    static let shared = SoundPlayer()
    private init() {}

    /// Play a system sound by name
    func play(_ soundName: String) {
        // Skip if sound is "None"
        guard soundName != "None" else { return }
        NSSound(named: soundName)?.play()
    }

    /// Play a system sound for an event using user preferences
    func playEvent(_ event: SystemSoundEvent, preferences: UserPreferences) {
        guard preferences.audioFeedbackEnabled else { return }

        let soundName: String
        switch event {
        case .recordingStart:
            soundName = preferences.recordingStartSound
        case .recordingStop:
            soundName = preferences.recordingStopSound
        case .processingComplete:
            soundName = preferences.processingCompleteSound
        case .error:
            soundName = preferences.errorSound
        case .paste:
            soundName = preferences.pasteSound
        }

        play(soundName)
    }

    /// List all available system sounds
    static func listAvailableSystemSounds() -> [String] {
        return [
            "Basso",
            "Blow",
            "Bottle",
            "Frog",
            "Funk",
            "Glass",
            "Hero",
            "Morse",
            "Ping",
            "Pop",
            "Purr",
            "Sosumi",
            "Submarine",
            "Tink"
        ]
    }
}
