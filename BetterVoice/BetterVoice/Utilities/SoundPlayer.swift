//
//  SoundPlayer.swift
//  BetterVoice
//
//  Play system sounds for audio feedback
//  Uses macOS built-in sounds instead of custom files
//

import Foundation
import AppKit

enum SystemSound: String {
    case recordingStart = "Ping"        // Subtle ping sound
    case recordingStop = "Pop"          // Pop sound
    case processingComplete = "Glass"   // Success chime
    case error = "Basso"               // Alert sound
    case paste = "Morse"               // Quick beep

    // Alternative sounds you can use:
    // "Blow", "Bottle", "Frog", "Funk", "Hero", "Submarine", "Tink"
}

final class SoundPlayer {

    static let shared = SoundPlayer()
    private init() {}

    /// Play a system sound
    func play(_ sound: SystemSound) {
        NSSound(named: sound.rawValue)?.play()
    }

    /// Play a system sound if audio feedback is enabled
    func playIfEnabled(_ sound: SystemSound, preferences: UserPreferences) {
        guard preferences.audioFeedbackEnabled else { return }
        play(sound)
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
