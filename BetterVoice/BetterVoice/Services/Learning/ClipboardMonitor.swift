//
//  ClipboardMonitor.swift
//  BetterVoice
//
//  Hybrid monitoring: Accessibility API + Clipboard
//  Detects user edits via focused text field (primary) or clipboard (fallback)
//  Detects significant changes (>10% difference) per FR-017
//  Timeout calculation: 1 minute per 100 characters (min 2 min, max 10 min)
//

import Foundation
import AppKit

enum LearningDetectionMethod {
    case accessibility
    case clipboard
}

final class ClipboardMonitor {

    // MARK: - Singleton

    static let shared = ClipboardMonitor()
    private init() {}

    // MARK: - Dependencies

    private let accessibilityReader = AccessibilityTextReader.shared

    // MARK: - Properties

    private var isMonitoring = false
    private var originalText: String?
    private var editedText: String?
    private var detectionMethod: LearningDetectionMethod?
    private var monitoringTask: Task<Void, Never>?
    private var lastChangeCount: Int = 0
    private var lastAccessibilityCheck: Date?
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

    /// Start hybrid monitoring (Accessibility + Clipboard)
    func startMonitoring(originalText: String, timeout: TimeInterval) async {
        self.originalText = originalText
        self.editedText = nil
        self.detectionMethod = nil
        self.isMonitoring = true
        self.lastChangeCount = NSPasteboard.general.changeCount
        self.lastAccessibilityCheck = Date()
        self.startTime = Date()

        Logger.shared.info("Started hybrid monitoring for \(Int(timeout))s (\(originalText.count) chars)")

        // Start background monitoring task
        monitoringTask = Task {
            await monitorHybrid(timeout: timeout)
        }
    }

    /// Stop monitoring
    func stopMonitoring() async {
        guard isMonitoring else { return }

        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil

        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
        let method = detectionMethod.map { "\($0)" } ?? "none"
        Logger.shared.info("Stopped monitoring after \(Int(elapsed))s (detected via: \(method))")
    }

    /// Get edited text if detected
    func getEditedText() async -> String? {
        return editedText
    }

    /// Get detection method used
    var currentDetectionMethod: LearningDetectionMethod? {
        return detectionMethod
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

    /// Hybrid monitoring: Accessibility API (every 5s) + Clipboard (every 500ms)
    private func monitorHybrid(timeout: TimeInterval) async {
        let startTime = Date()
        let clipboardCheckInterval: TimeInterval = 0.5 // Check every 500ms
        let accessibilityCheckInterval: TimeInterval = 5.0 // Check every 5 seconds

        while isMonitoring && Date().timeIntervalSince(startTime) < timeout {
            // 1. Check clipboard (fast, every 500ms)
            if await checkClipboard() {
                break // Found edit
            }

            // 2. Check accessibility (slower, every 5 seconds)
            if let lastCheck = lastAccessibilityCheck,
               Date().timeIntervalSince(lastCheck) >= accessibilityCheckInterval {
                if await checkAccessibility() {
                    break // Found edit
                }
                lastAccessibilityCheck = Date()
            }

            // Wait before next check
            try? await Task.sleep(nanoseconds: UInt64(clipboardCheckInterval * 1_000_000_000))
        }

        Logger.shared.debug("Hybrid monitoring completed")
    }

    /// Check clipboard for changes
    private func checkClipboard() async -> Bool {
        let currentChangeCount = NSPasteboard.general.changeCount

        guard currentChangeCount != lastChangeCount else { return false }

        lastChangeCount = currentChangeCount

        // Get clipboard content
        guard let clipboardString = NSPasteboard.general.string(forType: .string),
              let original = originalText,
              clipboardString != original else {
            return false
        }

        // Calculate difference
        let distance = calculateEditDistance(original, clipboardString)
        let maxLength = max(original.count, clipboardString.count)

        guard maxLength > 0 else { return false }

        let similarity = 1.0 - (Double(distance) / Double(maxLength))

        // Significant change if <90% similar (>10% different)
        if similarity < 0.9 {
            editedText = clipboardString
            detectionMethod = .clipboard
            Logger.shared.info("✓ Detected edit via CLIPBOARD: \(Int(similarity * 100))% similar")
            isMonitoring = false
            return true
        }

        return false
    }

    /// Check focused text field via Accessibility API
    private func checkAccessibility() async -> Bool {
        // Get focused text field content
        guard let focusedText = accessibilityReader.getFocusedTextFieldContent(),
              let original = originalText,
              focusedText != original else {
            return false
        }

        // Calculate difference
        let distance = calculateEditDistance(original, focusedText)
        let maxLength = max(original.count, focusedText.count)

        guard maxLength > 0 else { return false }

        let similarity = 1.0 - (Double(distance) / Double(maxLength))

        // Significant change if <90% similar (>10% different)
        if similarity < 0.9 {
            editedText = focusedText
            detectionMethod = .accessibility
            let appName = accessibilityReader.getFocusedApplicationName() ?? "unknown"
            Logger.shared.info("✓ Detected edit via ACCESSIBILITY (\(appName)): \(Int(similarity * 100))% similar")
            isMonitoring = false
            return true
        }

        return false
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
