//
//  ClipboardMonitor.swift
//  BetterVoice
//
//  Monitors clipboard for user edits after paste with variable timeout
//  Detects significant changes (>10% difference) per FR-017
//  Timeout calculation: 1 minute per 100 characters (min 2 min, max 10 min)
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
    private var startTime: Date?

    // MARK: - Public Methods

    /// Calculate timeout based on text length: 1 minute per 100 characters (min 2 min, max 10 min)
    static func calculateTimeout(for text: String) -> TimeInterval {
        let charactersPerMinute = 100.0
        let minimumTimeout: TimeInterval = 120 // 2 minutes
        let maximumTimeout: TimeInterval = 600 // 10 minutes

        let calculatedTimeout = TimeInterval(text.count) / charactersPerMinute * 60.0
        return min(max(calculatedTimeout, minimumTimeout), maximumTimeout)
    }

    /// Start monitoring clipboard for changes
    func startMonitoring(originalText: String, timeout: TimeInterval) async {
        self.originalText = originalText
        self.editedText = nil
        self.isMonitoring = true
        self.lastChangeCount = NSPasteboard.general.changeCount
        self.startTime = Date()

        Logger.shared.info("Started clipboard monitoring for \(Int(timeout))s (\(originalText.count) chars)")

        // Start background monitoring task
        monitoringTask = Task {
            await monitorClipboard(timeout: timeout)
        }
    }

    /// Stop monitoring
    func stopMonitoring() async {
        guard isMonitoring else { return }

        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil

        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
        Logger.shared.info("Stopped clipboard monitoring after \(Int(elapsed))s")
    }

    /// Get edited text if detected
    func getEditedText() async -> String? {
        return editedText
    }

    /// Check if currently monitoring
    var isActive: Bool {
        return isMonitoring
    }

    /// Get remaining monitoring time
    func getRemainingTime(timeout: TimeInterval) -> TimeInterval? {
        guard let startTime = startTime, isMonitoring else { return nil }
        let elapsed = Date().timeIntervalSince(startTime)
        return max(0, timeout - elapsed)
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
