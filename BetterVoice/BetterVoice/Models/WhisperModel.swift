//
//  WhisperModel.swift
//  BetterVoice
//
//  Model representing a Whisper transcription model
//  Supports 5 model sizes: tiny, base, small, medium, large
//

import Foundation

enum WhisperModelSize: String, Codable, CaseIterable {
    case tiny
    case base
    case small
    case medium
    case large

    var displayName: String {
        rawValue.capitalized
    }
}

struct WhisperModel: Codable, Identifiable {
    let id: UUID
    let size: WhisperModelSize
    let fileName: String
    let fileSize: Int64
    let storageURL: URL
    var isDownloaded: Bool
    var downloadedDate: Date?
    var lastUsed: Date?
    let checksumSHA256: String
    let modelVersion: String

    // Default initializer
    init(
        id: UUID = UUID(),
        size: WhisperModelSize,
        fileName: String,
        fileSize: Int64,
        storageURL: URL,
        isDownloaded: Bool = false,
        downloadedDate: Date? = nil,
        lastUsed: Date? = nil,
        checksumSHA256: String,
        modelVersion: String
    ) {
        self.id = id
        self.size = size
        self.fileName = fileName
        self.fileSize = fileSize
        self.storageURL = storageURL
        self.isDownloaded = isDownloaded
        self.downloadedDate = downloadedDate
        self.lastUsed = lastUsed
        self.checksumSHA256 = checksumSHA256
        self.modelVersion = modelVersion
    }

    // Model size constants (FR-004)
    static let modelSizes: [WhisperModelSize: (fileName: String, bytes: Int64)] = [
        .tiny: ("ggml-tiny.bin", 75_497_472),
        .base: ("ggml-base.bin", 142_356_992),
        .small: ("ggml-small.bin", 466_043_136),
        .medium: ("ggml-medium.bin", 1_533_341_696),
        .large: ("ggml-large.bin", 2_946_424_832)
    ]

    // Computed property for display size
    var displaySize: String {
        let gb = Double(fileSize) / 1_073_741_824.0
        let mb = Double(fileSize) / 1_048_576.0

        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }

    // Computed property for download status
    var needsDownload: Bool {
        return !isDownloaded
    }
}
