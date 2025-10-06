//
//  AudioRecording.swift
//  BetterVoice
//
//  Model representing a single audio recording session
//  Conforms to Codable for persistence
//

import Foundation

struct AudioRecording: Codable, Identifiable {
    let id: UUID
    let duration: TimeInterval
    let sampleRate: Int
    let channels: Int
    let format: String
    let filePath: String
    let timestamp: Date
    let fileSize: Int64

    // Default initializer
    init(
        id: UUID = UUID(),
        duration: TimeInterval,
        sampleRate: Int,
        channels: Int,
        format: String,
        filePath: String,
        timestamp: Date = Date(),
        fileSize: Int64
    ) {
        self.id = id
        self.duration = duration
        self.sampleRate = sampleRate
        self.channels = channels
        self.format = format
        self.filePath = filePath
        self.timestamp = timestamp
        self.fileSize = fileSize
    }

    // FR-029: Maximum recording duration is 2 hours (7200 seconds)
    var isValid: Bool {
        return duration > 0 &&
               duration <= 7200 &&
               sampleRate == 16000 &&
               channels == 1 &&
               format == "PCM16" &&
               fileSize > 0
    }

    // Computed property for display
    var displayDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
