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
            // Calculate edit distance
            let distance = calculateEditDistance(originalText, editedText)
            let similarity = 1.0 - (Double(distance) / Double(max(originalText.count, editedText.count)))

            // Only learn from significant edits (>10% change)
            if similarity < 0.9 {
                do {
                    try storePattern(
                        original: originalText,
                        edited: editedText,
                        documentType: documentType
                    )
                    Logger.shared.info("Stored learning pattern: \(similarity * 100)% similarity")
                } catch {
                    Logger.shared.error("Failed to store learning pattern", error: error)
                }
            }
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

    /// Apply learned patterns to improve text
    func applyLearned(
        text: String,
        documentType: DocumentType
    ) throws -> String {
        var improved = text

        // Find similar patterns
        let patterns = try findSimilarPatterns(text: text, documentType: documentType)

        // Apply the most confident pattern
        if let bestPattern = patterns.first, bestPattern.confidence > 0.8 {
            // Simple replacement for now
            // In production, this would use more sophisticated pattern matching
            improved = bestPattern.editedText

            // Increment pattern frequency
            try databaseManager.incrementPatternFrequency(bestPattern.id!)

            Logger.shared.info("Applied learned pattern with confidence \(bestPattern.confidence)")
        }

        return improved
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
