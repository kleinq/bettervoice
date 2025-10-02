//
//  ClipboardMonitor.swift
//  BetterVoice
//
//  Monitors clipboard for user edits after paste (10-second observation window)
//  Detects significant changes (>10% difference) per FR-017
//

import Foundation
import AppKit

final class ClipboardMonitor {

    // MARK: - Singleton

    static let shared = ClipboardMonitor()
    private init() {}

    // MARK: - Properties

    private var isMonitoring = false
    private var originalText: String?
    private var editedText: String?
    private var monitoringTask: Task<Void, Never>?
    private var lastChangeCount: Int = 0

    // MARK: - Public Methods

    /// Start monitoring clipboard for changes
    func startMonitoring(originalText: String, timeout: TimeInterval) async {
        self.originalText = originalText
        self.editedText = nil
        self.isMonitoring = true
        self.lastChangeCount = NSPasteboard.general.changeCount

        Logger.shared.debug("Started clipboard monitoring for \(timeout)s")

        // Start background monitoring task
        monitoringTask = Task {
            await monitorClipboard(timeout: timeout)
        }
    }

    /// Stop monitoring
    func stopMonitoring() async {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil

        Logger.shared.debug("Stopped clipboard monitoring")
    }

    /// Get edited text if detected
    func getEditedText() async -> String? {
        return editedText
    }

    // MARK: - Private Methods

    private func monitorClipboard(timeout: TimeInterval) async {
        let startTime = Date()
        let checkInterval: TimeInterval = 0.5 // Check every 500ms

        while isMonitoring && Date().timeIntervalSince(startTime) < timeout {
            // Check if clipboard changed
            let currentChangeCount = NSPasteboard.general.changeCount

            if currentChangeCount != lastChangeCount {
                lastChangeCount = currentChangeCount

                // Get clipboard content
                if let clipboardString = NSPasteboard.general.string(forType: .string) {
                    // Check if it's different from original
                    if let original = originalText, clipboardString != original {
                        // Calculate difference
                        let distance = calculateEditDistance(original, clipboardString)
                        let maxLength = max(original.count, clipboardString.count)

                        if maxLength > 0 {
                            let similarity = 1.0 - (Double(distance) / Double(maxLength))

                            // Significant change if <90% similar (>10% different)
                            if similarity < 0.9 {
                                editedText = clipboardString
                                Logger.shared.info("Detected significant clipboard edit: \(Int(similarity * 100))% similar")

                                // Stop monitoring after first significant edit
                                isMonitoring = false
                                break
                            }
                        }
                    }
                }
            }

            // Wait before next check
            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }

        Logger.shared.debug("Clipboard monitoring completed")
    }

    /// Calculate Levenshtein distance
    private func calculateEditDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count

        // Handle edge cases
        if m == 0 { return n }
        if n == 0 { return m }

        // Create DP table
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        // Initialize
        for i in 0...m {
            dp[i][0] = i
        }
        for j in 0...n {
            dp[0][j] = j
        }

        // Fill table
        for i in 1...m {
            for j in 1...n {
                if s1Array[i - 1] == s2Array[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = 1 + min(
                        dp[i - 1][j],     // deletion
                        dp[i][j - 1],     // insertion
                        dp[i - 1][j - 1]  // substitution
                    )
                }
            }
        }

        return dp[m][n]
    }
}
