//
//  EditBuffer.swift
//  BetterVoice
//
//  Smart edit buffering with adaptive debouncing
//  Groups related edits and detects edit completion
//

import Foundation

// MARK: - Edit Snapshot

struct EditSnapshot {
    let timestamp: Date
    let text: String
}

// MARK: - Edit Buffer

final class EditBuffer {

    // MARK: - Properties

    private let originalText: String
    private let timeout: TimeInterval
    private var snapshots: [EditSnapshot] = []
    private var keystrokeVelocities: [TimeInterval] = []
    private var debounceTimer: Timer?
    private var lastSnapshotTime: Date?

    // Callback when edit is complete
    var onEditComplete: ((String, String) -> Void)?

    // MARK: - Initialization

    init(originalText: String, timeout: TimeInterval) {
        self.originalText = originalText
        self.timeout = timeout
    }

    deinit {
        debounceTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Add a new text snapshot
    func addSnapshot(_ text: String) {
        let now = Date()

        // Calculate keystroke velocity
        if let lastTime = lastSnapshotTime {
            let velocity = now.timeIntervalSince(lastTime)
            keystrokeVelocities.append(velocity)

            // Keep only last 10 velocities for rolling average
            if keystrokeVelocities.count > 10 {
                keystrokeVelocities.removeFirst()
            }
        }

        // Add snapshot
        snapshots.append(EditSnapshot(timestamp: now, text: text))
        lastSnapshotTime = now

        Logger.shared.debug("📝 Edit snapshot added (\(snapshots.count) total)")

        // Reset debounce timer
        resetDebounceTimer()
    }

    /// Flush pending edits immediately
    func flush() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        processEditSession()
    }

    // MARK: - Private Methods

    private func resetDebounceTimer() {
        debounceTimer?.invalidate()

        let debounceInterval = calculateAdaptiveDebounce()

        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.processEditSession()
        }

        Logger.shared.debug("⏱️ Debounce timer reset: \(String(format: "%.1f", debounceInterval))s")
    }

    private func calculateAdaptiveDebounce() -> TimeInterval {
        guard !keystrokeVelocities.isEmpty else {
            return 2.0 // Default
        }

        let avgVelocity = keystrokeVelocities.reduce(0.0, +) / Double(keystrokeVelocities.count)

        if avgVelocity < 0.1 {
            // Fast typer (< 100ms between keystrokes)
            return 1.5
        } else if avgVelocity < 0.3 {
            // Normal speed
            return 2.0
        } else {
            // Slow/careful typer
            return 3.0
        }
    }

    private func processEditSession() {
        guard !snapshots.isEmpty else { return }

        // Get first and last snapshots
        let firstSnapshot = snapshots.first!
        let lastSnapshot = snapshots.last!

        Logger.shared.info("✅ Edit session complete: \(snapshots.count) snapshots over \(String(format: "%.1f", lastSnapshot.timestamp.timeIntervalSince(firstSnapshot.timestamp)))s")

        // Compare original vs final
        let editedText = lastSnapshot.text

        if editedText != originalText {
            Logger.shared.info("📊 Change detected: \(originalText.count) → \(editedText.count) chars")
            onEditComplete?(originalText, editedText)
        } else {
            Logger.shared.debug("No actual changes detected (cursor movement only)")
        }

        // Clear buffer
        snapshots.removeAll()
        keystrokeVelocities.removeAll()
        lastSnapshotTime = nil
    }
}
