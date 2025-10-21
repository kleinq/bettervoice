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

        let lowercased = trimmed.lowercased()
        let words = trimmed.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return .statement }

        let firstWord = words[0].lowercased()
            .trimmingCharacters(in: .punctuationCharacters)

        // Check for question indicators at the start
        if questionWords.contains(firstWord) {
            return .question
        }

        // Check for tag questions at the end (isn't it, don't you, can't we, etc.)
        let tagQuestionPatterns = [
            "isn't it", "aren't they", "wasn't it", "weren't they",
            "don't you", "doesn't it", "didn't they",
            "can't you", "couldn't you", "won't you", "wouldn't you",
            "shouldn't you", "isn't that", "right"
        ]
        for pattern in tagQuestionPatterns {
            if lowercased.hasSuffix(pattern) {
                return .question
            }
        }

        // Check for questions with "or" (Is it this or that?)
        if lowercased.contains(" or ") && questionWords.contains(firstWord) {
            return .question
        }

        // Check for indirect questions that start with question words
        // "what can we do", "how should I", "why would you", etc.
        if words.count >= 3 {
            let secondWord = words[1].lowercased()
                .trimmingCharacters(in: .punctuationCharacters)

            // WH-word + modal/auxiliary verb patterns
            let questionStarters = ["what", "how", "why", "when", "where", "which", "who"]
            let modalsAndAux = ["can", "could", "should", "would", "will", "shall", "do", "does", "did", "is", "are", "was", "were", "have", "has", "had"]

            if questionStarters.contains(firstWord) && modalsAndAux.contains(secondWord) {
                return .question
            }
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        // Split into sentences (rough split on ., !, ?)
        let sentences = splitIntoSentences(trimmed)

        // Analyze and punctuate each sentence
        let punctuatedSentences = sentences.map { sentence -> String in
            var result = sentence.trimmingCharacters(in: .whitespacesAndNewlines)

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

        return punctuatedSentences.joined(separator: " ")
    }

    /// Split text into sentences
    private func splitIntoSentences(_ text: String) -> [String] {
        // Split on sentence boundaries (., !, ?)
        let pattern = #"[.!?]+"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [text]
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        var sentences: [String] = []
        var lastEnd = 0

        for match in matches {
            let sentenceRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            let sentence = nsString.substring(with: sentenceRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !sentence.isEmpty {
                sentences.append(sentence)
            }

            lastEnd = match.range.location + match.range.length
        }

        // Add remaining text if any
        if lastEnd < nsString.length {
            let remaining = nsString.substring(from: lastEnd)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !remaining.isEmpty {
                sentences.append(remaining)
            }
        }

        // If no sentences were found, return the whole text
        return sentences.isEmpty ? [text] : sentences
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
                result += capitalizeSentence(currentSentence, isFirst: result.isEmpty)
                currentSentence = ""
            }
        }

        // Add remaining text
        if !currentSentence.isEmpty {
            result += capitalizeSentence(currentSentence, isFirst: result.isEmpty)
        }

        return result
    }

    private func capitalizeSentence(_ sentence: String, isFirst: Bool) -> String {
        // For non-first sentences, preserve leading space
        let leadingSpace = !isFirst && sentence.hasPrefix(" ") ? " " : ""
        let trimmed = sentence.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return sentence }

        // Find first letter and capitalize it
        var chars = Array(trimmed)
        for i in 0..<chars.count {
            if chars[i].isLetter {
                chars[i] = Character(chars[i].uppercased())
                break
            }
        }

        return leadingSpace + String(chars)
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
