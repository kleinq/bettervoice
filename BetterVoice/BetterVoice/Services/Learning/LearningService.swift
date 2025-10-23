//
//  LearningService.swift
//  BetterVoice
//
//  Learning system that improves transcription quality from user edits
//  Uses edit distance and pattern matching (FR-017, QR-004)
//

import Foundation
import GRDB

// MARK: - Protocol

protocol LearningServiceProtocol {
    func observe(originalText: String, documentType: DocumentType, timeoutSeconds: Int) async
    func findSimilarPatterns(text: String, documentType: DocumentType, threshold: Double) throws -> [LearningPattern]
    func applyLearned(text: String, documentType: DocumentType) throws -> String
}

// MARK: - Service Implementation

final class LearningService: LearningServiceProtocol {

    // MARK: - Singleton

    static let shared = LearningService()
    private init() {}

    // MARK: - Dependencies

    private let databaseManager = DatabaseManager.shared
    private let patternRecognizer = PatternRecognizer.shared
    private let clipboardMonitor = ClipboardMonitor.shared

    // MARK: - Public Methods

    /// Monitor clipboard for user edits after paste (10-second window)
    func observe(
        originalText: String,
        documentType: DocumentType,
        timeoutSeconds: Int = 10
    ) async {
        Logger.shared.info("Starting learning observation for \(documentType.rawValue)")

        // Start clipboard monitoring
        await clipboardMonitor.startMonitoring(
            originalText: originalText,
            timeout: TimeInterval(timeoutSeconds)
        )

        // Wait for timeout or edit detection
        try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds) * 1_000_000_000)

        // Check if user edited the text
        if let editedText = await clipboardMonitor.getEditedText() {
            // Calculate edit distance for logging
            let distance = calculateEditDistance(originalText, editedText)
            let similarity = 1.0 - (Double(distance) / Double(max(originalText.count, editedText.count)))

            // Learn from ANY change - user intent is the signal!
            if editedText != originalText {
                do {
                    let method = clipboardMonitor.currentDetectionMethod
                    let methodStr = method == .accessibility ? "Accessibility" : "Clipboard"

                    try storePattern(
                        original: originalText,
                        edited: editedText,
                        documentType: documentType
                    )

                    // Detailed logging
                    Logger.shared.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    Logger.shared.info("✓ LEARNING PATTERN SAVED")
                    Logger.shared.info("Detection: \(methodStr)")
                    Logger.shared.info("Document Type: \(documentType.rawValue)")
                    Logger.shared.info("Similarity: \(String(format: "%.1f", similarity * 100))%")
                    Logger.shared.info("Change: \(distance) character edits")
                    Logger.shared.info("Original (\(originalText.count) chars): \"\(originalText.prefix(50))...\"")
                    Logger.shared.info("Edited (\(editedText.count) chars): \"\(editedText.prefix(50))...\"")
                    Logger.shared.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                } catch {
                    Logger.shared.error("Failed to store learning pattern", error: error)
                }
            } else {
                Logger.shared.debug("No changes detected - text identical")
            }
        } else {
            Logger.shared.debug("No edits detected within timeout period")
        }

        await clipboardMonitor.stopMonitoring()
    }

    /// Find similar patterns in the database (>80% similarity threshold)
    func findSimilarPatterns(
        text: String,
        documentType: DocumentType,
        threshold: Double = 0.8
    ) throws -> [LearningPattern] {
        // Query patterns for this document type
        let patterns = try databaseManager.fetchLearningPatterns(for: documentType, minimumConfidence: threshold)

        // Calculate similarity for each pattern
        var matchedPatterns: [(pattern: LearningPattern, similarity: Double)] = []

        for pattern in patterns {
            let distance = calculateEditDistance(text, pattern.originalText)
            let similarity = 1.0 - (Double(distance) / Double(max(text.count, pattern.originalText.count)))

            if similarity >= threshold {
                matchedPatterns.append((pattern, similarity))
            }
        }

        // Sort by similarity (highest first)
        matchedPatterns.sort { $0.similarity > $1.similarity }

        return matchedPatterns.map { $0.pattern }
    }

    /// Apply learned patterns to improve text using token-level replacements
    func applyLearned(
        text: String,
        documentType: DocumentType
    ) throws -> String {
        var improved = text

        // Get all high-confidence patterns for this document type
        let patterns = try databaseManager.fetchLearningPatterns(for: documentType, minimumConfidence: 0.7)

        // Extract token-level replacements from patterns
        var replacements: [(from: String, to: String)] = []

        for pattern in patterns {
            // Find word-level differences between original and edited
            let tokenReplacements = extractTokenReplacements(
                original: pattern.originalText,
                edited: pattern.editedText
            )
            replacements.append(contentsOf: tokenReplacements)
        }

        // SAFETY CHECK: Detect corrupted learning patterns
        // If too many replacements or they contain suspicious characters, skip application
        if replacements.count > 100 {
            Logger.shared.warning("⚠️ Learning patterns appear corrupted (\(replacements.count) replacements). Skipping application. Clear learning database to fix.")
            return text
        }

        // Check for corrupted patterns (unicode blocks, file paths, etc.)
        let suspiciousPatterns = replacements.filter { replacement in
            let combined = replacement.from + replacement.to
            // Check for box drawing characters, file paths, or very long strings
            return combined.contains("▐") || combined.contains("█") || combined.contains("▛") ||
                   combined.contains("/") && combined.contains(".swift") ||
                   replacement.to.count > 50
        }

        if !suspiciousPatterns.isEmpty {
            Logger.shared.warning("⚠️ Learning patterns contain corrupted data (\(suspiciousPatterns.count) suspicious patterns). Skipping application. Clear learning database to fix.")
            return text
        }

        // Apply replacements (case-insensitive, whole word matching)
        for replacement in replacements {
            improved = applyTokenReplacement(
                text: improved,
                from: replacement.from,
                to: replacement.to
            )
        }

        if improved != text {
            Logger.shared.info("Applied \(replacements.count) learned pattern(s)")
        }

        return improved
    }

    /// Extract word-level differences between original and edited text
    private func extractTokenReplacements(original: String, edited: String) -> [(from: String, to: String)] {
        let originalWords = original.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let editedWords = edited.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var replacements: [(from: String, to: String)] = []

        // Simple alignment: find words that changed
        let minLength = min(originalWords.count, editedWords.count)
        for i in 0..<minLength {
            let origWord = originalWords[i].trimmingCharacters(in: .punctuationCharacters)
            let editWord = editedWords[i].trimmingCharacters(in: .punctuationCharacters)

            // If words differ and aren't too short (avoid common words)
            if origWord.lowercased() != editWord.lowercased() && origWord.count >= 3 {
                replacements.append((from: origWord, to: editWord))
            }
        }

        return replacements
    }

    /// Apply case-insensitive whole-word replacement
    private func applyTokenReplacement(text: String, from: String, to: String) -> String {
        // Use word boundaries to avoid partial matches
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: from))\\b"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        let result = regex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: to
        )

        return result
    }

    // MARK: - Private Methods

    private func storePattern(
        original: String,
        edited: String,
        documentType: DocumentType
    ) throws {
        // Check if similar pattern exists
        let existingPatterns = try findSimilarPatterns(text: original, documentType: documentType, threshold: 0.95)

        if let existing = existingPatterns.first {
            // Increment frequency of existing pattern
            try databaseManager.incrementPatternFrequency(existing.id!)
        } else {
            // Create new pattern
            var pattern = LearningPattern(
                id: nil,
                documentType: documentType,
                originalText: original,
                editedText: edited,
                frequency: 1,
                lastSeen: Date(),
                confidence: 1.0
            )

            try databaseManager.saveLearningPattern(&pattern)
        }
    }

    /// Calculate Levenshtein distance (edit distance)
    private func calculateEditDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count

        // Create DP table
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        // Initialize base cases
        for i in 0...m {
            dp[i][0] = i
        }
        for j in 0...n {
            dp[0][j] = j
        }

        // Fill DP table
        for i in 1...m {
            for j in 1...n {
                if s1Array[i - 1] == s2Array[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = 1 + min(
                        dp[i - 1][j],    // deletion
                        dp[i][j - 1],    // insertion
                        dp[i - 1][j - 1] // substitution
                    )
                }
            }
        }

        return dp[m][n]
    }
}
