//
//  TranscriptionJob.swift
//  BetterVoice
//
//  Model representing a transcription job lifecycle
//  Tracks status transitions and performance metrics
//

import Foundation

enum TranscriptionStatus: String, Codable {
    case queued
    case modelLoading
    case transcribing
    case completed
    case failed
}

struct TranscriptionJob: Codable, Identifiable {
    let id: UUID
    let recordingID: UUID
    var status: TranscriptionStatus
    let modelSize: WhisperModelSize
    let queuedAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var transcribedText: String?
    var errorMessage: String?

    // Default initializer
    init(
        id: UUID = UUID(),
        recordingID: UUID,
        status: TranscriptionStatus = .queued,
        modelSize: WhisperModelSize,
        queuedAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        transcribedText: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.recordingID = recordingID
        self.status = status
        self.modelSize = modelSize
        self.queuedAt = queuedAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.transcribedText = transcribedText
        self.errorMessage = errorMessage
    }

    // Computed property for processing duration
    var processingDuration: TimeInterval? {
        guard let start = startedAt, let end = completedAt else {
            return nil
        }
        return end.timeIntervalSince(start)
    }

    // Computed property for completion status
    var isComplete: Bool {
        return status == .completed || status == .failed
    }
}
