//
//  FillerWordRemover.swift
//  BetterVoice
//
//  Pattern-based removal of filler words with context awareness
//

import Foundation

final class FillerWordRemover {

    // MARK: - Singleton

    static let shared = FillerWordRemover()
    private init() {}

    // MARK: - Filler Patterns

    private let fillerPatterns: [String] = [
        "um", "uh", "like", "you know", "I mean", "basically", "actually",
        "sort of", "kind of", "literally", "right", "okay", "so yeah",
        "you see", "well", "hmm", "err", "ah"
    ]

    // Words that shouldn't be removed in certain contexts
    private let protectedContexts: [String: [String]] = [
        "like": ["would like", "looks like", "seems like", "feels like", "tastes like"],
        "right": ["turn right", "on the right", "right now", "all right"],
        "so": ["and so", "or so", "if so"]
    ]

    // MARK: - Public Methods

    func remove(from text: String) -> (cleanedText: String, removedFillers: [String]) {
        var cleanedText = text
        var removedFillers: [String] = []

        // Process each filler pattern
        for filler in fillerPatterns {
            let result = removeFiller(filler, from: cleanedText)
            cleanedText = result.text
            removedFillers.append(contentsOf: result.removed)
        }

        // Clean up extra spaces
        cleanedText = cleanExtraSpaces(cleanedText)

        return (cleanedText, removedFillers)
    }

    // MARK: - Private Methods

    private func removeFiller(_ filler: String, from text: String) -> (text: String, removed: [String]) {
        var cleanedText = text
        var removed: [String] = []

        // Create regex pattern for the filler word
        // Match word boundaries to avoid partial matches
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: filler))\\b"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return (text, [])
        }

        // Find all matches
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        // Process matches in reverse order to maintain string indices
        for match in matches.reversed() {
            guard let range = Range(match.range, in: text) else { continue }

            let matchedText = String(text[range])
            let context = getContext(for: range, in: text)

            // Check if this occurrence should be protected
            if shouldProtect(filler: filler, in: context) {
                continue
            }

            // Remove the filler
            cleanedText = cleanedText.replacingCharacters(in: range, with: "")
            removed.append(matchedText)
        }

        return (cleanedText, removed)
    }

    private func getContext(for range: Range<String.Index>, in text: String) -> String {
        let contextLength = 20

        // Get characters before the match
        let beforeStart = text.index(range.lowerBound, offsetBy: -contextLength, limitedBy: text.startIndex) ?? text.startIndex
        let before = String(text[beforeStart..<range.lowerBound])

        // Get characters after the match
        let afterEnd = text.index(range.upperBound, offsetBy: contextLength, limitedBy: text.endIndex) ?? text.endIndex
        let after = String(text[range.upperBound..<afterEnd])

        return before + "<FILLER>" + after
    }

    private func shouldProtect(filler: String, in context: String) -> Bool {
        guard let protectedPhrases = protectedContexts[filler.lowercased()] else {
            return false
        }

        let lowerContext = context.lowercased()

        // Check if any protected phrase is in the context
        return protectedPhrases.contains { phrase in
            lowerContext.contains(phrase.lowercased())
        }
    }

    private func cleanExtraSpaces(_ text: String) -> String {
        var cleaned = text

        // Replace multiple spaces with single space
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }

        // Remove spaces before punctuation
        cleaned = cleaned.replacingOccurrences(of: " ,", with: ",")
        cleaned = cleaned.replacingOccurrences(of: " .", with: ".")
        cleaned = cleaned.replacingOccurrences(of: " ?", with: "?")
        cleaned = cleaned.replacingOccurrences(of: " !", with: "!")

        // Trim leading/trailing whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }
}
