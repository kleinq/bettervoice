//
//  DominantCharacteristicAnalyzer.swift
//  BetterVoice
//
//  Analyzes mixed signals and determines dominant category characteristics
//  Implements frequency-based voting across feature categories
//

import Foundation

/// Analyzes features to determine dominant category when signals are mixed
final class DominantCharacteristicAnalyzer {

    // MARK: - Public Interface

    /// Analyze features and determine dominant category
    /// - Parameters:
    ///   - text: Original text
    ///   - features: Extracted text features
    ///   - mlPrediction: ML model's predicted category
    /// - Returns: Final category based on dominant characteristics
    func analyze(text: String, features: TextFeatures, mlPrediction: DocumentType) -> DocumentType {
        // Count votes for each category based on features
        var scores: [DocumentType: Int] = [
            .email: 0,
            .message: 0,
            .document: 0,
            .social: 0,
            .code: 0,
            .search: 0
        ]

        // Email indicators
        if features.hasGreeting && features.formalityScore > 0.6 {
            scores[.email, default: 0] += 3
        }
        if features.hasSignature {
            scores[.email, default: 0] += 2
        }
        if features.formalityScore > 0.7 && features.averageSentenceLength > 15 {
            scores[.email, default: 0] += 2
        }

        // Message indicators
        if features.hasGreeting && features.formalityScore < 0.5 {
            scores[.message, default: 0] += 3
        }
        if features.wordCount < 30 && features.hasGreeting {
            scores[.message, default: 0] += 2
        }
        if !features.hasCompleteSentences && features.wordCount < 20 {
            scores[.message, default: 0] += 2
        }

        // Document indicators
        if features.wordCount > 100 {
            scores[.document, default: 0] += 2
        }
        if features.formalityScore > 0.8 {
            scores[.document, default: 0] += 3
        }
        if features.hasCompleteSentences && features.averageSentenceLength > 20 {
            scores[.document, default: 0] += 2
        }
        if features.sentenceCount > 5 {
            scores[.document, default: 0] += 1
        }

        // Social indicators
        if features.wordCount < 50 && !features.hasGreeting && !features.hasSignature {
            scores[.social, default: 0] += 2
        }
        if features.punctuationDensity > 0.15 { // Emoji and exclamations
            scores[.social, default: 0] += 2
        }
        if features.formalityScore < 0.3 && features.wordCount < 40 {
            scores[.social, default: 0] += 2
        }

        // Code indicators
        if features.technicalTermCount > 0 {
            scores[.code, default: 0] += features.technicalTermCount
        }
        if features.punctuationDensity > 0.2 && features.technicalTermCount > 0 {
            scores[.code, default: 0] += 2
        }
        if !features.hasCompleteSentences && features.technicalTermCount > 2 {
            scores[.code, default: 0] += 3
        }

        // Search indicators
        if features.wordCount <= 10 && !features.hasCompleteSentences {
            scores[.search, default: 0] += 3
        }
        if !features.hasGreeting && !features.hasSignature && features.wordCount < 15 {
            scores[.search, default: 0] += 2
        }
        if features.punctuationDensity < 0.05 && features.wordCount < 10 {
            scores[.search, default: 0] += 2
        }

        // Find category with highest score
        let sortedScores = scores.sorted { $0.value > $1.value }

        // If there's a clear winner (score difference > 1), return it
        if let first = sortedScores.first,
           let second = sortedScores.dropFirst().first,
           first.value > second.value {
            return first.key
        }

        // If tie or no clear dominant characteristics, defer to ML prediction
        return mlPrediction
    }
}
