//
//  WhisperService.swift
//  BetterVoice
//
//  Whisper.cpp integration for local voice transcription
//  Conforms to WhisperServiceProtocol with <3s for 30s audio (PR-002)
//

import Foundation
import Combine

// MARK: - Protocol

protocol WhisperServiceProtocol {
    var isModelLoaded: Bool { get }
    var currentModel: WhisperModel? { get }
    var progressPublisher: AnyPublisher<Float, Never> { get }

    func loadModel(_ model: WhisperModel) async throws
    func transcribe(audioData: Data) async throws -> TranscriptionResult
    func cancel()
}

// MARK: - Result Types

struct TranscriptionResult {
    let text: String
    let detectedLanguage: String?
    let languageConfidence: Float
    let segments: [TranscriptionSegment]
    let processingTime: TimeInterval
}

struct TranscriptionSegment {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

// MARK: - Error Types

enum WhisperServiceError: Error {
    case modelNotLoaded
    case modelFileNotFound
    case invalidAudioData
    case transcriptionFailed(String)
    case cancelled
}

// MARK: - Service Implementation

final class WhisperService: WhisperServiceProtocol {

    // MARK: - Properties

    private(set) var isModelLoaded: Bool = false
    private(set) var currentModel: WhisperModel?

    private let progressSubject = PassthroughSubject<Float, Never>()
    var progressPublisher: AnyPublisher<Float, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    private var whisperContext: OpaquePointer?
    private var isCancelled = false
    private let processingQueue = DispatchQueue(label: "com.bettervoice.whisper", qos: .userInitiated)

    // MARK: - Public Methods

    func loadModel(_ model: WhisperModel) async throws {
        // Validate model file exists
        guard FileManager.default.fileExists(atPath: model.storageURL.path) else {
            Logger.shared.error("Whisper model file not found at: \(model.storageURL.path)")
            throw WhisperServiceError.modelFileNotFound
        }

        // Unload previous model if loaded
        if isModelLoaded {
            unloadModel()
        }

        // Load model on background queue
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WhisperServiceError.transcriptionFailed("Service deallocated"))
                    return
                }

                do {
                    // Initialize whisper.cpp context
                    // NOTE: This is a placeholder - actual whisper.cpp integration requires C++ bridging
                    // For now, we simulate model loading
                    try self.loadWhisperContext(modelPath: model.storageURL.path)

                    self.currentModel = model
                    self.isModelLoaded = true

                    Logger.shared.info("Loaded Whisper model: \(model.size.rawValue) from \(model.storageURL.lastPathComponent)")
                    continuation.resume()
                } catch {
                    Logger.shared.error("Failed to load Whisper model", error: error)
                    continuation.resume(throwing: WhisperServiceError.transcriptionFailed("Failed to load model: \(error.localizedDescription)"))
                }
            }
        }
    }

    func transcribe(audioData: Data) async throws -> TranscriptionResult {
        guard isModelLoaded else {
            throw WhisperServiceError.modelNotLoaded
        }

        guard audioData.count >= 16000 * 2 else { // At least 0.5s of PCM16 @ 16kHz
            throw WhisperServiceError.invalidAudioData
        }

        isCancelled = false

        // Perform transcription on background queue
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WhisperServiceError.transcriptionFailed("Service deallocated"))
                    return
                }

                let startTime = Date()

                do {
                    // Convert Data to float array for whisper.cpp
                    let audioSamples = self.convertPCM16ToFloat(audioData)

                    // Check for cancellation
                    if self.isCancelled {
                        continuation.resume(throwing: WhisperServiceError.cancelled)
                        return
                    }

                    // Perform transcription
                    // NOTE: This is a placeholder - actual whisper.cpp integration requires C++ bridging
                    let transcriptionText = try self.performWhisperTranscription(samples: audioSamples)

                    // Check for cancellation
                    if self.isCancelled {
                        continuation.resume(throwing: WhisperServiceError.cancelled)
                        return
                    }

                    // Extract segments and metadata
                    let segments = self.extractSegments()
                    let language = self.getDetectedLanguage()
                    let confidence = self.getLanguageConfidence()

                    let processingTime = Date().timeIntervalSince(startTime)

                    let result = TranscriptionResult(
                        text: transcriptionText,
                        detectedLanguage: language,
                        languageConfidence: confidence,
                        segments: segments,
                        processingTime: processingTime
                    )

                    Logger.shared.info("Transcription complete in \(String(format: "%.2f", processingTime))s: \(transcriptionText.prefix(50))...")

                    continuation.resume(returning: result)
                } catch {
                    Logger.shared.error("Transcription failed", error: error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func cancel() {
        isCancelled = true
        Logger.shared.info("Transcription cancellation requested")
    }

    // MARK: - Private Methods - Whisper.cpp Integration

    private func loadWhisperContext(modelPath: String) throws {
        // Use whisper.cpp C bridge
        whisperContext = whisper_bridge_init(modelPath)

        guard whisperContext != nil else {
            throw WhisperServiceError.transcriptionFailed("Failed to initialize whisper context")
        }
    }

    private func performWhisperTranscription(samples: [Float]) throws -> String {
        guard let context = whisperContext else {
            throw WhisperServiceError.modelNotLoaded
        }

        // Use whisper bridge for transcription
        guard let resultCString = whisper_bridge_transcribe(
            context,
            samples,
            Int32(samples.count),
            "en",  // English
            false  // No translation
        ) else {
            throw WhisperServiceError.transcriptionFailed("Whisper transcription returned nil")
        }

        let result = String(cString: resultCString)
        free(resultCString) // Free the C string allocated by the bridge

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractSegments() -> [TranscriptionSegment] {
        // NOTE: Placeholder for actual segment extraction from whisper.cpp
        // Actual implementation would extract from whisper_context
        /*
        var segments: [TranscriptionSegment] = []
        let segmentCount = whisper_full_n_segments(whisperContext)

        for i in 0..<segmentCount {
            let startTime = TimeInterval(whisper_full_get_segment_t0(whisperContext, i)) / 100.0
            let endTime = TimeInterval(whisper_full_get_segment_t1(whisperContext, i)) / 100.0

            if let text = whisper_full_get_segment_text(whisperContext, i) {
                let segment = TranscriptionSegment(
                    startTime: startTime,
                    endTime: endTime,
                    text: String(cString: text)
                )
                segments.append(segment)
            }
        }

        return segments
        */

        // Placeholder segments
        return []
    }

    private func getDetectedLanguage() -> String? {
        // NOTE: Placeholder for language detection from whisper.cpp
        // Actual: whisper_lang_str(whisper_full_lang_id(whisperContext))
        return "en"
    }

    private func getLanguageConfidence() -> Float {
        // NOTE: Placeholder for confidence score from whisper.cpp
        // Actual implementation would extract from whisper context
        return 0.95
    }

    private func unloadModel() {
        if let context = whisperContext {
            whisper_bridge_free(context)
        }
        whisperContext = nil
        currentModel = nil
        isModelLoaded = false
        Logger.shared.info("Unloaded Whisper model")
    }

    // MARK: - Audio Conversion

    private func convertPCM16ToFloat(_ data: Data) -> [Float] {
        let sampleCount = data.count / MemoryLayout<Int16>.size
        var floatSamples = [Float](repeating: 0, count: sampleCount)

        data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }

            for i in 0..<sampleCount {
                // Convert Int16 (-32768 to 32767) to Float (-1.0 to 1.0)
                floatSamples[i] = Float(baseAddress[i]) / Float(Int16.max)
            }
        }

        return floatSamples
    }

    // MARK: - Cleanup

    deinit {
        if isModelLoaded {
            unloadModel()
        }
    }
}
