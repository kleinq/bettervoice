//
//  PatternRecognizer.swift
//  BetterVoice
//
//  Identifies and manages recurring editing patterns with confidence scoring
//

import Foundation

final class PatternRecognizer {

    // MARK: - Singleton

    static let shared = PatternRecognizer()
    private init() {}

    // MARK: - Dependencies

    private let databaseManager = DatabaseManager.shared

    // MARK: - Constants

    private let minConfidenceThreshold = 0.3
    private let patternExpiryDays = 30

    // MARK: - Public Methods

    /// Identify recurring patterns and update confidence scores
    func analyzePatterns(documentType: DocumentType) throws {
        let patterns = try databaseManager.fetchLearningPatterns(for: documentType, minimumConfidence: 0.0)

        for var pattern in patterns {
            // Calculate confidence based on frequency and recency
            let confidence = calculateConfidence(pattern)
            pattern.confidence = confidence

            // Update pattern in database
            try databaseManager.saveLearningPattern(&pattern)

            Logger.shared.debug("Updated pattern confidence: \(confidence) for pattern \(pattern.id ?? 0)")
        }
    }

    /// Prune low-confidence patterns older than 30 days
    func pruneLowConfidencePatterns() throws {
        // Use the database manager's cleanup method
        try databaseManager.deleteOldPatterns(olderThan: patternExpiryDays)
        Logger.shared.info("Pruned low-confidence patterns older than \(patternExpiryDays) days")
    }

    /// Identify the most valuable patterns for a document type
    func getTopPatterns(
        documentType: DocumentType,
        limit: Int = 10
    ) throws -> [LearningPattern] {
        let patterns = try databaseManager.fetchLearningPatterns(for: documentType, minimumConfidence: 0.0)

        // Sort by confidence and frequency
        let sorted = patterns.sorted { p1, p2 in
            let score1 = p1.confidence * Double(p1.frequency)
            let score2 = p2.confidence * Double(p2.frequency)
            return score1 > score2
        }

        return Array(sorted.prefix(limit))
    }

    // MARK: - Private Methods

    /// Calculate confidence score based on frequency and recency
    private func calculateConfidence(_ pattern: LearningPattern) -> Double {
        // Base confidence from frequency
        let frequencyScore = min(1.0, Double(pattern.frequency) / 10.0)

        // Recency bonus (decay over time)
        let daysSinceLastSeen = Calendar.current.dateComponents(
            [.day],
            from: pattern.lastSeen,
            to: Date()
        ).day ?? 0

        let recencyScore: Double
        if daysSinceLastSeen < 7 {
            recencyScore = 1.0
        } else if daysSinceLastSeen < 30 {
            recencyScore = 0.7
        } else {
            recencyScore = 0.3
        }

        // Weighted combination
        let confidence = (frequencyScore * 0.7) + (recencyScore * 0.3)

        return confidence
    }

    /// Detect if a pattern represents a significant edit
    func isSignificantEdit(original: String, edited: String) -> Bool {
        // Must have meaningful difference (>10% change)
        let distance = levenshteinDistance(original, edited)
        let maxLength = max(original.count, edited.count)

        guard maxLength > 0 else { return false }

        let similarity = 1.0 - (Double(distance) / Double(maxLength))

        // Significant if <90% similar (>10% different)
        return similarity < 0.9
    }

    // MARK: - Helper Methods

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m {
            dp[i][0] = i
        }
        for j in 0...n {
            dp[0][j] = j
        }

        for i in 1...m {
            for j in 1...n {
                if s1Array[i - 1] == s2Array[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = 1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
                }
            }
        }

        return dp[m][n]
    }
}
