//
//  TranscriptionQueue.swift
//  BetterVoice
//
//  Queue management for transcription jobs with serial processing and priority support
//

import Foundation
import Combine

final class TranscriptionQueue {

    // MARK: - Singleton

    static let shared = TranscriptionQueue()

    // MARK: - Properties

    private let queueSubject = PassthroughSubject<QueueUpdate, Never>()
    var queuePublisher: AnyPublisher<QueueUpdate, Never> {
        queueSubject.eraseToAnyPublisher()
    }

    private var queue: [QueuedTranscription] = []
    private var isProcessing = false
    private let queueLock = NSLock()
    private let processingQueue = DispatchQueue(label: "com.bettervoice.transcription-queue", qos: .userInitiated)

    private let whisperService: WhisperService

    // MARK: - Initialization

    private init(whisperService: WhisperService = WhisperService()) {
        self.whisperService = whisperService
    }

    // MARK: - Public Methods

    func enqueue(_ job: TranscriptionJob, audioData: Data, priority: TranscriptionPriority = .normal) {
        queueLock.lock()
        defer { queueLock.unlock() }

        let queuedItem = QueuedTranscription(
            job: job,
            audioData: audioData,
            priority: priority,
            enqueuedAt: Date()
        )

        // Insert based on priority
        if priority == .high {
            // High priority goes to front (after any other high priority items)
            if let lastHighPriorityIndex = queue.lastIndex(where: { $0.priority == .high }) {
                queue.insert(queuedItem, at: lastHighPriorityIndex + 1)
            } else {
                queue.insert(queuedItem, at: 0)
            }
        } else {
            // Normal priority goes to end
            queue.append(queuedItem)
        }

        Logger.shared.info("Enqueued transcription job: \(job.id) with priority: \(priority)")

        // Notify queue update
        queueSubject.send(QueueUpdate(
            queueLength: queue.count,
            currentJob: isProcessing ? queue.first?.job : nil
        ))

        // Start processing if not already running
        if !isProcessing {
            processNext()
        }
    }

    func cancel(_ jobID: UUID) {
        queueLock.lock()
        defer { queueLock.unlock() }

        // Remove from queue if not yet processing
        if let index = queue.firstIndex(where: { $0.job.id == jobID }) {
            _ = queue.remove(at: index)
            Logger.shared.info("Cancelled queued transcription: \(jobID)")

            queueSubject.send(QueueUpdate(
                queueLength: queue.count,
                currentJob: isProcessing ? queue.first?.job : nil
            ))
        } else {
            // If currently processing, cancel the whisper service
            if queue.first?.job.id == jobID {
                whisperService.cancel()
                Logger.shared.info("Cancelled active transcription: \(jobID)")
            }
        }
    }

    func clearQueue() {
        queueLock.lock()
        defer { queueLock.unlock() }

        queue.removeAll()
        Logger.shared.info("Cleared transcription queue")

        queueSubject.send(QueueUpdate(
            queueLength: 0,
            currentJob: nil
        ))
    }

    func getQueueLength() -> Int {
        queueLock.lock()
        defer { queueLock.unlock() }
        return queue.count
    }

    func getCurrentJob() -> TranscriptionJob? {
        queueLock.lock()
        defer { queueLock.unlock() }
        return isProcessing ? queue.first?.job : nil
    }

    // MARK: - Private Methods

    private func processNext() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            self.queueLock.lock()

            guard !self.queue.isEmpty else {
                self.isProcessing = false
                self.queueLock.unlock()
                Logger.shared.debug("Transcription queue empty")
                return
            }

            self.isProcessing = true
            let queuedItem = self.queue.first!
            self.queueLock.unlock()

            Logger.shared.info("Processing transcription job: \(queuedItem.job.id)")

            // Process the transcription
            Task {
                let result: TranscriptionResult?
                let error: Error?

                do {
                    result = try await self.processTranscription(queuedItem)
                    error = nil
                } catch let e {
                    result = nil
                    error = e
                }

                // Remove from queue and process next (on main queue to avoid lock issues)
                await MainActor.run {
                    // Log errors
                    if let error = error {
                        Logger.shared.error("Transcription failed for job: \(queuedItem.job.id)", error: error)
                    }

                    // Update job status
                    if let result = result {
                        self.completeJob(queuedItem.job, result: result)
                    } else if let error = error {
                        self.failJob(queuedItem.job, error: error)
                    }

                    self.queueLock.lock()
                    if !self.queue.isEmpty && self.queue.first?.job.id == queuedItem.job.id {
                        self.queue.removeFirst()
                    }
                    let remainingCount = self.queue.count
                    self.queueLock.unlock()

                    self.queueSubject.send(QueueUpdate(
                        queueLength: remainingCount,
                        currentJob: remainingCount > 0 ? self.queue.first?.job : nil
                    ))

                    // Process next job
                    if remainingCount > 0 {
                        self.processNext()
                    } else {
                        self.isProcessing = false
                    }
                }
            }
        }
    }

    private func processTranscription(_ queuedItem: QueuedTranscription) async throws -> TranscriptionResult {
        let job = queuedItem.job

        // Ensure model is loaded
        if !whisperService.isModelLoaded || whisperService.currentModel?.size != job.modelSize {
            let model = ModelStorage.shared.getModelInfo(job.modelSize)
            try await whisperService.loadModel(model)
        }

        // Perform transcription
        let result = try await whisperService.transcribe(audioData: queuedItem.audioData)

        return result
    }

    private func completeJob(_ job: TranscriptionJob, result: TranscriptionResult) {
        // Update job status
        var updatedJob = job
        updatedJob.status = .completed
        updatedJob.completedAt = Date()
        updatedJob.transcribedText = result.text

        Logger.shared.info("Transcription completed: \(job.id) - \(result.text.prefix(50))...")

        // TODO: Persist updated job to database or notify observers
    }

    private func failJob(_ job: TranscriptionJob, error: Error) {
        // Update job status
        var updatedJob = job
        updatedJob.status = .failed
        updatedJob.completedAt = Date()
        updatedJob.errorMessage = error.localizedDescription

        Logger.shared.error("Transcription failed: \(job.id)")

        // TODO: Persist updated job or notify observers
    }
}

// MARK: - Supporting Types

struct QueuedTranscription {
    let job: TranscriptionJob
    let audioData: Data
    let priority: TranscriptionPriority
    let enqueuedAt: Date
}

enum TranscriptionPriority {
    case normal
    case high
}

struct QueueUpdate {
    let queueLength: Int
    let currentJob: TranscriptionJob?
}
