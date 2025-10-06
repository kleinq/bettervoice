//
//  WhisperModelTests.swift
//  BetterVoiceTests
//
//  Unit tests for WhisperModel model
//  Tests MUST FAIL until implementation (TDD Red phase)
//

import XCTest
@testable import BetterVoice

final class WhisperModelTests: XCTestCase {

    func testWhisperModelIsEncodableAndDecodable() throws {
        // Given
        let model = WhisperModel(
            id: UUID(),
            size: .base,
            fileName: "ggml-base.bin",
            fileSize: 142_356_992,
            storageURL: URL(fileURLWithPath: "/Library/Application Support/BetterVoice/models/ggml-base.bin"),
            isDownloaded: true,
            downloadedDate: Date(),
            lastUsed: Date(),
            checksumSHA256: "abc123def456",
            modelVersion: "1.0"
        )

        // When
        let encoded = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(WhisperModel.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.id, model.id)
        XCTAssertEqual(decoded.size, model.size)
        XCTAssertEqual(decoded.fileName, model.fileName)
    }

    func testModelSizeConstants() {
        // Given
        let expectedSizes: [(WhisperModelSize, String, Int64)] = [
            (.tiny, "ggml-tiny.bin", 75_497_472),
            (.base, "ggml-base.bin", 142_356_992),
            (.small, "ggml-small.bin", 466_043_136),
            (.medium, "ggml-medium.bin", 1_533_341_696),
            (.large, "ggml-large.bin", 2_946_424_832)
        ]

        // Then
        for (size, expectedFileName, expectedBytes) in expectedSizes {
            let sizeInfo = WhisperModel.modelSizes[size]
            XCTAssertNotNil(sizeInfo, "\(size) should have size info")
            XCTAssertEqual(sizeInfo?.fileName, expectedFileName)
            XCTAssertEqual(sizeInfo?.bytes, expectedBytes)
        }
    }

    func testDisplaySizeFormatting() {
        // Given
        let tinyModel = WhisperModel(
            id: UUID(),
            size: .tiny,
            fileName: "ggml-tiny.bin",
            fileSize: 75_497_472, // ~75 MB
            storageURL: URL(fileURLWithPath: "/tmp/ggml-tiny.bin"),
            isDownloaded: false,
            downloadedDate: nil,
            lastUsed: nil,
            checksumSHA256: "checksum",
            modelVersion: "1.0"
        )

        let largeModel = WhisperModel(
            id: UUID(),
            size: .large,
            fileName: "ggml-large.bin",
            fileSize: 2_946_424_832, // ~2.9 GB
            storageURL: URL(fileURLWithPath: "/tmp/ggml-large.bin"),
            isDownloaded: false,
            downloadedDate: nil,
            lastUsed: nil,
            checksumSHA256: "checksum",
            modelVersion: "1.0"
        )

        // When
        let tinyDisplay = tinyModel.displaySize
        let largeDisplay = largeModel.displaySize

        // Then
        XCTAssertTrue(tinyDisplay.contains("MB"), "Tiny model should display in MB")
        XCTAssertTrue(largeDisplay.contains("GB"), "Large model should display in GB")
    }

    func testNeedsDownloadProperty() {
        // Given: Downloaded model
        let downloaded = WhisperModel(
            id: UUID(),
            size: .base,
            fileName: "ggml-base.bin",
            fileSize: 142_356_992,
            storageURL: URL(fileURLWithPath: "/tmp/ggml-base.bin"),
            isDownloaded: true,
            downloadedDate: Date(),
            lastUsed: nil,
            checksumSHA256: "checksum",
            modelVersion: "1.0"
        )

        // Then
        XCTAssertFalse(downloaded.needsDownload, "Downloaded model should not need download")

        // Given: Not downloaded
        let notDownloaded = WhisperModel(
            id: UUID(),
            size: .small,
            fileName: "ggml-small.bin",
            fileSize: 466_043_136,
            storageURL: URL(fileURLWithPath: "/tmp/ggml-small.bin"),
            isDownloaded: false,
            downloadedDate: nil,
            lastUsed: nil,
            checksumSHA256: "checksum",
            modelVersion: "1.0"
        )

        // Then
        XCTAssertTrue(notDownloaded.needsDownload, "Model not downloaded should need download")
    }

    func testStorageURLValidation() {
        // Given: Valid storage URL in Application Support (FR-015)
        let validURL = URL(fileURLWithPath: "/Users/test/Library/Application Support/BetterVoice/models/ggml-base.bin")

        let model = WhisperModel(
            id: UUID(),
            size: .base,
            fileName: "ggml-base.bin",
            fileSize: 142_356_992,
            storageURL: validURL,
            isDownloaded: true,
            downloadedDate: Date(),
            lastUsed: nil,
            checksumSHA256: "checksum",
            modelVersion: "1.0"
        )

        // Then
        XCTAssertTrue(model.storageURL.path.contains("Application Support/BetterVoice/models"))
    }

    func testLastUsedTracking() {
        // Given: Model used recently
        let recentlyUsed = WhisperModel(
            id: UUID(),
            size: .base,
            fileName: "ggml-base.bin",
            fileSize: 142_356_992,
            storageURL: URL(fileURLWithPath: "/tmp/model.bin"),
            isDownloaded: true,
            downloadedDate: Date().addingTimeInterval(-86400), // 1 day ago
            lastUsed: Date(), // Just used
            checksumSHA256: "checksum",
            modelVersion: "1.0"
        )

        // Then
        XCTAssertNotNil(recentlyUsed.lastUsed)
        XCTAssertGreaterThan(recentlyUsed.lastUsed!, recentlyUsed.downloadedDate!)
    }
}
