//
//  ModelDownloadService.swift
//  BetterVoice
//
//  Download Whisper models from Hugging Face with progress tracking and validation
//

import Foundation
import Combine
import CryptoKit

final class ModelDownloadService: NSObject {

    // MARK: - Singleton

    static let shared = ModelDownloadService()
    private override init() {
        super.init()
    }

    // MARK: - Properties

    private let progressSubject = PassthroughSubject<DownloadProgress, Never>()
    var progressPublisher: AnyPublisher<DownloadProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    private var activeDownloads: [WhisperModelSize: URLSessionDownloadTask] = [:]
    private lazy var downloadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes
        config.timeoutIntervalForResource = 3600 // 1 hour for large models
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // Model download URLs (Hugging Face)
    private let modelURLs: [WhisperModelSize: String] = [
        .tiny: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin",
        .base: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin",
        .small: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin",
        .medium: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin",
        .large: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"
    ]

    // Expected SHA256 checksums for validation
    private let modelChecksums: [WhisperModelSize: String] = [
        .tiny: "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21",
        .base: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe",
        .small: "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b",
        .medium: "6c14d5adee5f86394037b4e4e8b59f1673b8b3d0c5a84433b3b5f7f1a0e9de7d",
        .large: "ad82bf6a9043ceed055076d0fd39f5f186ff8062db2b0a6c7d8f87d7c8e6f0f1"
    ]

    // MARK: - Public Methods

    func downloadModel(_ model: WhisperModel) async throws -> URL {
        guard let downloadURL = modelURLs[model.size] else {
            throw ModelDownloadError.invalidModelSize
        }

        // Check if already downloaded and valid
        if model.isDownloaded && FileManager.default.fileExists(atPath: model.storageURL.path) {
            Logger.shared.info("Model already downloaded: \(model.size.rawValue)")
            return model.storageURL
        }

        // Check if download already in progress
        if activeDownloads[model.size] != nil {
            throw ModelDownloadError.downloadAlreadyInProgress
        }

        Logger.shared.info("Starting download for \(model.size.rawValue) model from \(downloadURL)")

        // Create download task
        return try await withCheckedThrowingContinuation { continuation in
            guard let url = URL(string: downloadURL) else {
                continuation.resume(throwing: ModelDownloadError.invalidURL)
                return
            }

            let downloadTask = downloadSession.downloadTask(with: url) { [weak self] tempURL, response, error in
                guard let self = self else { return }

                // Remove from active downloads
                self.activeDownloads.removeValue(forKey: model.size)

                if let error = error {
                    Logger.shared.error("Model download failed", error: error)
                    continuation.resume(throwing: ModelDownloadError.downloadFailed(error.localizedDescription))
                    return
                }

                guard let tempURL = tempURL else {
                    continuation.resume(throwing: ModelDownloadError.downloadFailed("No temporary file"))
                    return
                }

                do {
                    // Validate checksum
                    try self.validateChecksum(fileURL: tempURL, expectedChecksum: self.modelChecksums[model.size] ?? "")

                    // Move to final location
                    let finalURL = model.storageURL
                    try? FileManager.default.removeItem(at: finalURL) // Remove if exists
                    try FileManager.default.moveItem(at: tempURL, to: finalURL)

                    Logger.shared.info("Model downloaded successfully: \(model.size.rawValue) to \(finalURL.path)")

                    continuation.resume(returning: finalURL)
                } catch {
                    Logger.shared.error("Model validation or move failed", error: error)
                    continuation.resume(throwing: error)
                }
            }

            activeDownloads[model.size] = downloadTask
            downloadTask.resume()
        }
    }

    func cancelDownload(for modelSize: WhisperModelSize) {
        guard let task = activeDownloads[modelSize] else { return }

        task.cancel()
        activeDownloads.removeValue(forKey: modelSize)

        Logger.shared.info("Cancelled download for \(modelSize.rawValue)")

        // Notify cancellation
        progressSubject.send(DownloadProgress(
            modelSize: modelSize,
            bytesDownloaded: 0,
            totalBytes: 0,
            progress: 0.0,
            state: .cancelled
        ))
    }

    // MARK: - Private Methods

    private func validateChecksum(fileURL: URL, expectedChecksum: String) throws {
        guard !expectedChecksum.isEmpty else {
            Logger.shared.warning("No checksum available for validation")
            return
        }

        let fileData = try Data(contentsOf: fileURL)
        let calculatedChecksum = fileData.sha256Hash()

        guard calculatedChecksum == expectedChecksum else {
            throw ModelDownloadError.checksumMismatch(expected: expectedChecksum, actual: calculatedChecksum)
        }

        Logger.shared.info("Checksum validation passed: \(calculatedChecksum)")
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloadService: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled in downloadTask completion handler
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // Find which model is being downloaded
        guard let modelSize = activeDownloads.first(where: { $0.value == downloadTask })?.key else { return }

        let progress = totalBytesExpectedToWrite > 0 ? Float(totalBytesWritten) / Float(totalBytesExpectedToWrite) : 0.0

        let downloadProgress = DownloadProgress(
            modelSize: modelSize,
            bytesDownloaded: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite,
            progress: progress,
            state: .downloading
        )

        progressSubject.send(downloadProgress)

        Logger.shared.debug("Download progress for \(modelSize.rawValue): \(String(format: "%.1f%%", progress * 100))")
    }
}

// MARK: - Supporting Types

struct DownloadProgress {
    let modelSize: WhisperModelSize
    let bytesDownloaded: Int64
    let totalBytes: Int64
    let progress: Float // 0.0 - 1.0
    let state: DownloadState
}

enum DownloadState {
    case waiting
    case downloading
    case completed
    case cancelled
    case failed
}

enum ModelDownloadError: Error {
    case invalidModelSize
    case invalidURL
    case downloadAlreadyInProgress
    case downloadFailed(String)
    case checksumMismatch(expected: String, actual: String)
    case fileSystemError(String)
}

// MARK: - SHA256 Extension

extension Data {
    func sha256Hash() -> String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
