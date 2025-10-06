//
//  FeatureExtractor.swift
//  BetterVoice
//
//  Extracts linguistic and structural features from text for classification
//

import Foundation
import NaturalLanguage

/// Extracts text features for classification analysis
final class FeatureExtractor {

    // MARK: - Properties

    private let sentenceTokenizer: NLTokenizer
    private let wordTokenizer: NLTokenizer
    private let tagger: NLTagger

    // Feature dictionaries
    private let greetings: Set<String> = ["hey", "hi", "hello", "dear", "greetings"]
    private let signatures: Set<String> = ["regards", "thanks", "best", "sincerely", "cheers", "thank you"]
    private let technicalTerms: Set<String> = [
        "function", "var", "let", "const", "def", "class", "struct", "enum",
        "import", "export", "return", "if", "else", "for", "while", "switch",
        "case", "break", "continue", "try", "catch", "throw", "async", "await",
        "func", "public", "private", "static", "final", "override", "init",
        "protocol", "extension", "typealias", "guard", "defer", "inout"
    ]
    private let formalWords: Set<String> = [
        "hereby", "pursuant", "therefore", "furthermore", "moreover", "consequently",
        "regards", "sincerely", "cordially", "respectfully", "kindly", "please",
        "attached", "enclosed", "following", "regarding", "concerning", "reference"
    ]

    // MARK: - Initialization

    init() {
        sentenceTokenizer = NLTokenizer(unit: .sentence)
        wordTokenizer = NLTokenizer(unit: .word)
        tagger = NLTagger(tagSchemes: [.lexicalClass, .language])
    }

    // MARK: - Public Interface

    /// Extract features from text
    /// - Parameter text: Input text to analyze
    /// - Returns: TextFeatures struct with extracted features
    func extract(from text: String) -> TextFeatures {
        // Set up tokenizers
        sentenceTokenizer.string = text
        wordTokenizer.string = text
        tagger.string = text

        // Extract basic counts
        let sentenceCount = countSentences(in: text)
        let wordCount = countWords(in: text)
        let averageSentenceLength = sentenceCount > 0 ? Double(wordCount) / Double(sentenceCount) : 0.0

        // Structural features
        let hasCompleteSentences = detectCompleteSentences(in: text)
        let punctuationDensity = calculatePunctuationDensity(in: text)

        // Content features
        let hasGreeting = detectGreeting(in: text)
        let hasSignature = detectSignature(in: text)
        let technicalTermCount = countTechnicalTerms(in: text)
        let formalityScore = calculateFormalityScore(in: text, wordCount: wordCount)

        return TextFeatures(
            sentenceCount: sentenceCount,
            wordCount: wordCount,
            averageSentenceLength: averageSentenceLength,
            hasCompleteSentences: hasCompleteSentences,
            formalityScore: formalityScore,
            technicalTermCount: technicalTermCount,
            punctuationDensity: punctuationDensity,
            hasGreeting: hasGreeting,
            hasSignature: hasSignature
        )
    }

    // MARK: - Private Feature Extraction Methods

    private func countSentences(in text: String) -> Int {
        var count = 0
        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            count += 1
            return true
        }
        return max(count, 1) // At least 1 sentence for non-empty text
    }

    private func countWords(in text: String) -> Int {
        var count = 0
        wordTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            count += 1
            return true
        }
        return count
    }

    private func detectCompleteSentences(in text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Check if text ends with sentence-ending punctuation
        let lastChar = trimmed.last
        return lastChar == "." || lastChar == "!" || lastChar == "?"
    }

    private func calculatePunctuationDensity(in text: String) -> Double {
        guard !text.isEmpty else { return 0.0 }

        let punctuationSet = CharacterSet.punctuationCharacters
        let punctuationCount = text.unicodeScalars.filter { punctuationSet.contains($0) }.count

        let density = Double(punctuationCount) / Double(text.count)
        return min(max(density, 0.0), 1.0) // Clamp to [0.0, 1.0]
    }

    private func detectGreeting(in text: String) -> Bool {
        let lowercased = text.lowercased()
        let words = lowercased.components(separatedBy: .whitespacesAndNewlines)

        // Check first 5 words for greetings
        let prefix = words.prefix(5)
        return prefix.contains(where: { greetings.contains($0) })
    }

    private func detectSignature(in text: String) -> Bool {
        let lowercased = text.lowercased()

        // Check for signature phrases
        for signature in signatures {
            if lowercased.contains(signature) {
                return true
            }
        }

        return false
    }

    private func countTechnicalTerms(in text: String) -> Int {
        let lowercased = text.lowercased()
        var count = 0

        // Count occurrences of technical terms
        for term in technicalTerms {
            // Use word boundaries to avoid partial matches
            let pattern = "\\b\(term)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(lowercased.startIndex..., in: lowercased)
                let matches = regex.numberOfMatches(in: lowercased, options: [], range: range)
                count += matches
            }
        }

        // Also check for code-like punctuation patterns
        let codePunctuation = ["()", "{}", "[]", "=>", "->", "==", "!=", "&&", "||"]
        for pattern in codePunctuation {
            if lowercased.contains(pattern) {
                count += 1
            }
        }

        return count
    }

    private func calculateFormalityScore(in text: String, wordCount: Int) -> Double {
        guard wordCount > 0 else { return 0.0 }

        let lowercased = text.lowercased()
        var formalityCount = 0

        // Count formal words
        for word in formalWords {
            if lowercased.contains(word) {
                formalityCount += 1
            }
        }

        // Adjust for sentence structure
        var score = Double(formalityCount) / Double(wordCount) * 10.0 // Scale up

        // Bonus for complete sentences and proper capitalization
        if detectCompleteSentences(in: text) {
            score += 0.2
        }

        // Penalty for casual markers (multiple exclamation marks, all caps words)
        if text.contains("!!") || text.contains("...") {
            score -= 0.2
        }

        // Check for all-caps words (yelling, informal)
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let capsWords = words.filter { word in
            word.count > 1 && word.uppercased() == word && word.rangeOfCharacter(from: .letters) != nil
        }
        if capsWords.count > 0 {
            score -= 0.1 * Double(capsWords.count)
        }

        // Clamp to [0.0, 1.0]
        return min(max(score, 0.0), 1.0)
    }
}
