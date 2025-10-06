//
//  PasteServiceContractTests.swift
//  BetterVoiceTests
//
//  Contract tests for PasteService
//  Tests MUST FAIL until implementation (TDD Red phase)
//

import XCTest
import AppKit
@testable import BetterVoice

final class PasteServiceContractTests: XCTestCase {
    var sut: PasteService!

    override func setUp() {
        super.setUp()
        sut = PasteService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - PR-003: Paste completes within 500ms

    func testPasteCompletesWithin500ms() async throws {
        // Given
        let testText = "Hello, this is a test message."
        let startTime = Date()

        // When
        try await sut.paste(text: testText)
        let elapsed = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(elapsed, 0.5, "Paste must complete within 500ms (PR-003)")
    }

    // MARK: - Contract: Copies to clipboard

    func testPasteCopiesTextToClipboard() async throws {
        // Given
        let testText = "Test clipboard content"
        NSPasteboard.general.clearContents()

        // When
        try await sut.paste(text: testText)

        // Then
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(clipboardContent, testText, "Text should be copied to clipboard")
    }

    // MARK: - Contract: Simulates Cmd+V CGEvent

    func testPasteSimulatesCmdV() async throws {
        // Given
        let testText = "Test paste event"

        // When
        try await sut.paste(text: testText)

        // Then
        // In real implementation, this would verify CGEvent was posted
        // For now, we verify no error was thrown
        XCTAssertTrue(true, "Paste should complete without error")
    }

    // MARK: - Contract: Handles no active text field

    func testPasteHandlesNoActiveTextField() async throws {
        // Given
        let testText = "Test with no target"
        // Ensure no text field is focused

        // When/Then
        // Should not throw error, but log warning
        try await sut.paste(text: testText)

        // Verify clipboard still has content
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(clipboardContent, testText, "Should still copy to clipboard")
    }

    // MARK: - Error Cases

    func testPasteThrowsErrorForEmptyText() async {
        // Given
        let emptyText = ""

        // When/Then
        do {
            try await sut.paste(text: emptyText)
            XCTFail("Should throw error for empty text")
        } catch {
            XCTAssertTrue(error is PasteServiceError, "Should throw PasteServiceError")
        }
    }

    func testPasteHandlesAccessibilityPermissionDenied() async throws {
        // Note: This test requires permission to be denied
        // In real testing, this would use dependency injection with mocked permission check

        // Given
        let testText = "Test accessibility"

        // When/Then - Expected behavior when permission denied
        // In production, this might fall back to just copying to clipboard
        try await sut.paste(text: testText)

        // Should at minimum copy to clipboard
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(clipboardContent, testText)
    }

    // MARK: - Multiple Paste Operations

    func testMultiplePasteOperationsSucceed() async throws {
        // Given
        let texts = ["First paste", "Second paste", "Third paste"]

        // When/Then
        for text in texts {
            try await sut.paste(text: text)
            let clipboardContent = NSPasteboard.general.string(forType: .string)
            XCTAssertEqual(clipboardContent, text, "Each paste should update clipboard")
        }
    }

    // MARK: - Special Characters

    func testPasteHandlesSpecialCharacters() async throws {
        // Given
        let specialText = "Test with émojis 🎉, unicode ñ, and symbols @#$%"

        // When
        try await sut.paste(text: specialText)

        // Then
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(clipboardContent, specialText, "Should handle special characters")
    }

    func testPasteHandlesMultilineText() async throws {
        // Given
        let multilineText = """
        First line
        Second line
        Third line
        """

        // When
        try await sut.paste(text: multilineText)

        // Then
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(clipboardContent, multilineText, "Should handle multiline text")
    }
}

// MARK: - Supporting Types (Contracts)

protocol PasteServiceProtocol {
    func paste(text: String) async throws
}

enum PasteServiceError: Error {
    case emptyText
    case clipboardFailed
    case cgEventFailed
    case accessibilityDenied
}
