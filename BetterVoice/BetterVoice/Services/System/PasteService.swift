//
//  PasteService.swift
//  BetterVoice
//
//  Paste text to active application via NSPasteboard + CGEvent
//  Meets <500ms paste operation (PR-003)
//

import Foundation
import AppKit
import CoreGraphics

// MARK: - Protocol

protocol PasteServiceProtocol {
    func paste(text: String) async throws
}

// MARK: - Error Types

enum PasteServiceError: Error {
    case emptyText
    case clipboardFailed
    case cgEventFailed
    case accessibilityDenied
}

// MARK: - Service Implementation

final class PasteService: PasteServiceProtocol {

    // MARK: - Singleton

    static let shared = PasteService()
    private init() {}

    // MARK: - Public Methods

    func paste(text: String) async throws {
        guard !text.isEmpty else {
            throw PasteServiceError.emptyText
        }

        // Copy text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let success = pasteboard.setString(text, forType: .string)
        guard success else {
            Logger.shared.error("Failed to copy text to clipboard")
            throw PasteServiceError.clipboardFailed
        }

        Logger.shared.debug("Copied \(text.count) characters to clipboard")

        // Simulate Cmd+V keypress using CGEvent
        try await simulateCmdV()

        Logger.shared.info("Paste operation completed successfully")
    }

    // MARK: - Private Methods

    private func simulateCmdV() async throws {
        // Check if accessibility permission is granted
        let trusted = AXIsProcessTrusted()
        guard trusted else {
            Logger.shared.warning("Accessibility permission not granted, skipping Cmd+V simulation")
            // Don't throw error - text is already on clipboard, user can paste manually
            return
        }

        // Create Cmd+V down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true) else {
            throw PasteServiceError.cgEventFailed
        }
        keyDownEvent.flags = .maskCommand

        // Create Cmd+V up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false) else {
            throw PasteServiceError.cgEventFailed
        }
        keyUpEvent.flags = .maskCommand

        // Post events to active application
        keyDownEvent.post(tap: .cghidEventTap)

        // Small delay between down and up (1ms)
        try await Task.sleep(nanoseconds: 1_000_000)

        keyUpEvent.post(tap: .cghidEventTap)

        Logger.shared.debug("Simulated Cmd+V keypress")
    }
}
