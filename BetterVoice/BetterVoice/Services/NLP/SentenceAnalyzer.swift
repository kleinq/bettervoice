//
//  SentenceAnalyzer.swift
//  BetterVoice
//
//  Analyzes sentence type and applies appropriate punctuation/capitalization
//

import Foundation
import NaturalLanguage

enum SentenceType {
    case question
    case statement
    case exclamation
    case command
}

actor SentenceAnalyzer {

    // Common question words
    private let questionWords = Set([
        "who", "what", "when", "where", "why", "how",
        "which", "whose", "whom",
        "can", "could", "would", "should", "will", "shall",
        "do", "does", "did", "is", "are", "was", "were",
        "has", "have", "had"
    ])

    // Command/imperative verbs
    private let commandVerbs = Set([
        "add", "create", "delete", "remove", "update", "change",
        "send", "write", "read", "open", "close",
        "start", "stop", "run", "execute",
        "show", "display", "hide", "find", "search"
    ])

    /// Analyze sentence type from text
    func analyzeSentenceType(_ text: String) -> SentenceType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .statement }

        let words = trimmed.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return .statement }

        let firstWord = words[0].lowercased()
            .trimmingCharacters(in: .punctuationCharacters)

        // Check for question indicators
        if questionWords.contains(firstWord) {
            return .question
        }

        // Check for command/imperative
        if commandVerbs.contains(firstWord) && words.count > 1 {
            return .command
        }

        // Check for inverted verb-subject (question pattern)
        if words.count >= 2 {
            let secondWord = words[1].lowercased()
                .trimmingCharacters(in: .punctuationCharacters)

            // "Is it...", "Are you...", "Can we...", "Would they..."
            if questionWords.contains(firstWord) &&
               ["i", "you", "we", "they", "it", "he", "she", "there"].contains(secondWord) {
                return .question
            }
        }

        // Check for exclamation patterns
        let lastWord = words.last?.lowercased() ?? ""
        if ["wow", "amazing", "incredible", "great", "awesome"].contains(lastWord) {
            return .exclamation
        }

        // Default to statement
        return .statement
    }

    /// Apply proper punctuation based on sentence type
    func applyPunctuation(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove existing ending punctuation
        while !result.isEmpty && CharacterSet(charactersIn: ".!?,;:").contains(result.unicodeScalars.last!) {
            result = String(result.dropLast())
        }

        let type = analyzeSentenceType(result)

        switch type {
        case .question:
            return result + "?"
        case .exclamation:
            return result + "!"
        case .command:
            return result + "."
        case .statement:
            return result + "."
        }
    }

    /// Capitalize sentences properly
    func capitalizeSentences(_ text: String) -> String {
        // Split into sentences (rough split on ., !, ?)
        let sentenceEndings = CharacterSet(charactersIn: ".!?")
        var result = ""
        var currentSentence = ""

        for char in text {
            currentSentence.append(char)

            if sentenceEndings.contains(char.unicodeScalars.first!) {
                // Capitalize first letter of sentence
                result += capitalizeSentence(currentSentence)
                currentSentence = ""
            }
        }

        // Add remaining text
        if !currentSentence.isEmpty {
            result += capitalizeSentence(currentSentence)
        }

        return result
    }

    private func capitalizeSentence(_ sentence: String) -> String {
        let trimmed = sentence.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return sentence }

        // Find first letter
        var chars = Array(trimmed)
        for i in 0..<chars.count {
            if chars[i].isLetter {
                chars[i] = Character(chars[i].uppercased())
                break
            }
        }

        return String(chars)
    }

    /// Full text enhancement: capitalize + punctuate
    func enhance(_ text: String, autoPunctuate: Bool = true, autoCapitalize: Bool = true) -> String {
        var result = text

        if autoPunctuate {
            result = applyPunctuation(result)
        }

        if autoCapitalize {
            result = capitalizeSentences(result)
        }

        return result
    }
}
