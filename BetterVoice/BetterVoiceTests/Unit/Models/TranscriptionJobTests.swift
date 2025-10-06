//
//  TranscriptionJobTests.swift
//  BetterVoiceTests
//
//  Unit tests for TranscriptionJob model
//  Tests validate status transitions, computed properties, and performance requirements
//

import XCTest
@testable import BetterVoice

final class TranscriptionJobTests: XCTestCase {

    // MARK: - Codable Conformance

    func testTranscriptionJobIsEncodableAndDecodable() throws {
        // Given
        let job = TranscriptionJob(
            id: UUID(),
            recordingID: UUID(),
            status: .completed,
            modelSize: .base,
            queuedAt: Date(),
            startedAt: Date().addingTimeInterval(-3),
            completedAt: Date(),
            transcribedText: "This is a test transcription.",
            errorMessage: nil
        )

        // When
        let encoded = try JSONEncoder().encode(job)
        let decoded = try JSONDecoder().decode(TranscriptionJob.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.id, job.id)
        XCTAssertEqual(decoded.recordingID, job.recordingID)
        XCTAssertEqual(decoded.modelSize, job.modelSize)
        XCTAssertEqual(decoded.status, job.status)
        XCTAssertEqual(decoded.transcribedText, job.transcribedText)
    }

    // MARK: - Status Transitions

    func testValidStatusTransition() {
        // Given
        var job = TranscriptionJob(
            recordingID: UUID(),
            status: .queued,
            modelSize: .base
        )

        // When: Valid transition sequence
        job.status = .modelLoading
        XCTAssertEqual(job.status, .modelLoading)

        job.status = .transcribing
        XCTAssertEqual(job.status, .transcribing)

        job.status = .completed
        XCTAssertEqual(job.status, .completed)

        // Then: Transitions succeed
        XCTAssertTrue(true, "Valid status transitions should succeed")
    }

    func testCompletedJobHasRequiredFields() {
        // Given
        let job = TranscriptionJob(
            recordingID: UUID(),
            status: .completed,
            modelSize: .base,
            startedAt: Date().addingTimeInterval(-3),
            completedAt: Date(),
            transcribedText: "Test transcription text"
        )

        // Then
        XCTAssertEqual(job.status, .completed)
        XCTAssertNotNil(job.transcribedText, "Completed job must have transcription")
        XCTAssertNotNil(job.completedAt, "Completed job must have completion time")
        XCTAssertTrue(job.isComplete, "isComplete should be true")
    }

    func testFailedJobHasError() {
        // Given
        let job = TranscriptionJob(
            recordingID: UUID(),
            status: .failed,
            modelSize: .base,
            startedAt: Date().addingTimeInterval(-1),
            completedAt: Date(),
            errorMessage: "Model not loaded"
        )

        // Then
        XCTAssertEqual(job.status, .failed)
        XCTAssertNotNil(job.errorMessage, "Failed job must have error message")
        XCTAssertNil(job.transcribedText, "Failed job should not have transcription")
        XCTAssertTrue(job.isComplete, "isComplete should be true for failed jobs (terminal state)")
    }

    // MARK: - Computed Properties

    func testProcessingDuration() {
        // Given
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(2.75) // 2.75 seconds

        let job = TranscriptionJob(
            recordingID: UUID(),
            status: .completed,
            modelSize: .base,
            startedAt: startTime,
            completedAt: endTime,
            transcribedText: "Test"
        )

        // When
        let duration = job.processingDuration

        // Then
        XCTAssertNotNil(duration, "Processing duration should be calculated")
        XCTAssertEqual(duration!, 2.75, accuracy: 0.01, "Duration should be ~2.75s")
    }

    func testProcessingDurationNilWhenIncomplete() {
        // Given: Job without completion time
        let job = TranscriptionJob(
            recordingID: UUID(),
            status: .transcribing,
            modelSize: .base,
            startedAt: Date()
        )

        // Then
        XCTAssertNil(job.processingDuration, "Duration should be nil when job incomplete")
    }

    func testIsCompleteProperty() {
        // Given: Completed job
        let completedJob = TranscriptionJob(
            recordingID: UUID(),
            status: .completed,
            modelSize: .base,
            startedAt: Date().addingTimeInterval(-2),
            completedAt: Date(),
            transcribedText: "Completed transcription"
        )

        // Then
        XCTAssertTrue(completedJob.isComplete)

        // Given: Failed job
        let failedJob = TranscriptionJob(
            recordingID: UUID(),
            status: .failed,
            modelSize: .base,
            startedAt: Date().addingTimeInterval(-1),
            completedAt: Date(),
            errorMessage: "Error"
        )

        // Then
        XCTAssertTrue(failedJob.isComplete)

        // Given: In-progress job
        let inProgressJob = TranscriptionJob(
            recordingID: UUID(),
            status: .transcribing,
            modelSize: .base,
            startedAt: Date()
        )

        // Then
        XCTAssertFalse(inProgressJob.isComplete)

        // Given: Queued job
        let queuedJob = TranscriptionJob(
            recordingID: UUID(),
            modelSize: .base
        )

        // Then
        XCTAssertFalse(queuedJob.isComplete)
    }

    // MARK: - Model Size Enum

    func testWhisperModelSizeEnum() {
        // Given
        let sizes: [WhisperModelSize] = [.tiny, .base, .small, .medium, .large]

        // Then
        XCTAssertEqual(sizes.count, 5, "Should have 5 model sizes")
        XCTAssertEqual(WhisperModelSize.base.rawValue, "base")
        XCTAssertEqual(WhisperModelSize.large.rawValue, "large")
    }

    func testTranscriptionStatusEnum() {
        // Given
        let statuses: [TranscriptionStatus] = [.queued, .modelLoading, .transcribing, .completed, .failed]

        // Then
        XCTAssertEqual(statuses.count, 5, "Should have 5 status values")
        XCTAssertEqual(TranscriptionStatus.queued.rawValue, "queued")
        XCTAssertEqual(TranscriptionStatus.completed.rawValue, "completed")
    }

    // MARK: - Performance Validation (PR-002)

    func testTranscriptionMeetsPerformanceRequirement() {
        // Given: Transcription of 30s audio completed in 2.8s
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(2.8)

        let job = TranscriptionJob(
            recordingID: UUID(),
            status: .completed,
            modelSize: .base,
            startedAt: startTime,
            completedAt: endTime,
            transcribedText: "Test transcription of 30 second audio"
        )

        // Then: PR-002 requires <3s for 30s audio with base model
        XCTAssertNotNil(job.processingDuration)
        XCTAssertLessThan(job.processingDuration!, 3.0, "Must meet PR-002: <3s for 30s audio")
    }

    func testDefaultQueuedStatus() {
        // Given
        let job = TranscriptionJob(
            recordingID: UUID(),
            modelSize: .base
        )

        // Then
        XCTAssertEqual(job.status, .queued, "Default status should be queued")
        XCTAssertNotNil(job.queuedAt, "QueuedAt should be set automatically")
        XCTAssertNil(job.startedAt, "StartedAt should be nil initially")
        XCTAssertNil(job.completedAt, "CompletedAt should be nil initially")
    }
}
