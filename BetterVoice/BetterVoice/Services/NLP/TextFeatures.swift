//
//  TextFeatures.swift
//  BetterVoice
//
//  Text feature extraction value type
//  Contains analyzed linguistic and structural features
//

import Foundation

struct TextFeatures: Codable {
    let sentenceCount: Int
    let wordCount: Int
    let averageSentenceLength: Double
    let hasCompleteSentences: Bool
    let formalityScore: Double  // 0.0-1.0
    let technicalTermCount: Int
    let punctuationDensity: Double  // 0.0-1.0
    let hasGreeting: Bool
    let hasSignature: Bool

    init(
        sentenceCount: Int,
        wordCount: Int,
        averageSentenceLength: Double,
        hasCompleteSentences: Bool,
        formalityScore: Double,
        technicalTermCount: Int,
        punctuationDensity: Double,
        hasGreeting: Bool,
        hasSignature: Bool
    ) {
        // Validation: counts must be >= 0
        self.sentenceCount = max(0, sentenceCount)
        self.wordCount = max(0, wordCount)
        self.averageSentenceLength = max(0.0, averageSentenceLength)
        self.hasCompleteSentences = hasCompleteSentences

        // Validation: scores must be in [0.0, 1.0]
        self.formalityScore = min(max(0.0, formalityScore), 1.0)
        self.punctuationDensity = min(max(0.0, punctuationDensity), 1.0)

        self.technicalTermCount = max(0, technicalTermCount)
        self.hasGreeting = hasGreeting
        self.hasSignature = hasSignature
    }

    /// Validation: all constraints satisfied
    var isValid: Bool {
        return sentenceCount >= 0 &&
               wordCount >= 0 &&
               averageSentenceLength >= 0.0 &&
               formalityScore >= 0.0 && formalityScore <= 1.0 &&
               punctuationDensity >= 0.0 && punctuationDensity <= 1.0 &&
               technicalTermCount >= 0
    }
}
