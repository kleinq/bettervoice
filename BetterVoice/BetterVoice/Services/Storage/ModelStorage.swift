//
//  ModelStorage.swift
//  BetterVoice
//
//  Manages Whisper model files in Application Support
//  FR-004: Model download and storage management
//

import Foundation

final class ModelStorage {
    static let shared = ModelStorage()

    private let modelsDirectory: URL

    // Model URLs (Hugging Face)
    private let modelURLs: [WhisperModelSize: String] = [
        .tiny: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin",
        .base: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin",
        .small: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin",
        .medium: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin",
        .large: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"
    ]

    // Expected SHA256 checksums (from whisper.cpp repository)
    private let modelChecksums: [WhisperModelSize: String] = [
        .tiny: "bd577a113a864445d4c299885e0cb97d4ba92b5f",
        .base: "465707469ff3a37a2b9b8d8f89f2f99de7299dac",
        .small: "55356645c2b361a969dfd0ef2c5a50d530afd8d5",
        .medium: "fd9727b6e1217c2f614f9b698455c4ffd82463b4",
        .large: "0f4c8e34f21cf1a914c59d8b3ce882345ad349d6"
    ]

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        modelsDirectory = appSupport
            .appendingPathComponent("BetterVoice", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: modelsDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Model Information

    func getModelPath(for size: WhisperModelSize) -> URL {
        return modelsDirectory.appendingPathComponent("ggml-\(size.rawValue).bin")
    }

    func isModelDownloaded(_ size: WhisperModelSize) -> Bool {
        let path = getModelPath(for: size)
        return FileManager.default.fileExists(atPath: path.path)
    }

    func getModelInfo(_ size: WhisperModelSize) -> WhisperModel {
        let path = getModelPath(for: size)
        let fileName = path.lastPathComponent
        let fileSize = WhisperModel.modelSizes[size]?.bytes ?? 0

        let isDownloaded = isModelDownloaded(size)
        let downloadedDate = isDownloaded ? getFileCreationDate(path) : nil

        return WhisperModel(
            size: size,
            fileName: fileName,
            fileSize: fileSize,
            storageURL: path,
            isDownloaded: isDownloaded,
            downloadedDate: downloadedDate,
            checksumSHA256: modelChecksums[size] ?? "",
            modelVersion: "v3"
        )
    }

    func listAllModels() -> [WhisperModel] {
        return WhisperModelSize.allCases.map { getModelInfo($0) }
    }

    // MARK: - Model Management

    func deleteModel(_ size: WhisperModelSize) throws {
        let path = getModelPath(for: size)
        guard FileManager.default.fileExists(atPath: path.path) else {
            return // Already deleted
        }

        try FileManager.default.removeItem(at: path)
    }

    func deleteAllModels() throws {
        for size in WhisperModelSize.allCases {
            try? deleteModel(size)
        }
    }

    func getTotalStorageUsed() -> Int64 {
        var total: Int64 = 0

        for size in WhisperModelSize.allCases {
            if isModelDownloaded(size) {
                let path = getModelPath(for: size)
                if let attributes = try? FileManager.default.attributesOfItem(atPath: path.path),
                   let fileSize = attributes[.size] as? Int64 {
                    total += fileSize
                }
            }
        }

        return total
    }

    func getModelURL(for size: WhisperModelSize) -> URL? {
        guard let urlString = modelURLs[size] else { return nil }
        return URL(string: urlString)
    }

    // MARK: - Verification

    func verifyModelChecksum(_ size: WhisperModelSize) throws -> Bool {
        let path = getModelPath(for: size)
        guard FileManager.default.fileExists(atPath: path.path) else {
            return false
        }

        // In production, compute SHA256 and compare
        // For now, just check file exists and has reasonable size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: path.path),
           let fileSize = attributes[.size] as? Int64 {
            let expectedSize = WhisperModel.modelSizes[size]?.bytes ?? 0
            // Allow 5% variance
            let tolerance = Int64(Double(expectedSize) * 0.05)
            return abs(fileSize - expectedSize) < tolerance
        }

        return false
    }

    // MARK: - Helpers

    private func getFileCreationDate(_ url: URL) -> Date? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.creationDate] as? Date
    }

    func getStorageInfo() -> StorageInfo {
        return StorageInfo(
            modelsDirectory: modelsDirectory,
            totalModels: WhisperModelSize.allCases.count,
            downloadedModels: WhisperModelSize.allCases.filter { isModelDownloaded($0) }.count,
            totalSizeBytes: getTotalStorageUsed()
        )
    }
}

// Storage info model
struct StorageInfo {
    let modelsDirectory: URL
    let totalModels: Int
    let downloadedModels: Int
    let totalSizeBytes: Int64

    var totalSizeMB: Double {
        Double(totalSizeBytes) / 1_048_576.0
    }

    var totalSizeGB: Double {
        Double(totalSizeBytes) / 1_073_741_824.0
    }
}
