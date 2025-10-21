//
//  SelfCorrectionHandler.swift
//  BetterVoice
//
//  Detects and removes self-corrections in transcribed text
//  Examples: "oh no", "I mean", "actually", "wait"
//

import Foundation

final class SelfCorrectionHandler {

    // MARK: - Singleton

    static let shared = SelfCorrectionHandler()
    private init() {}

    // MARK: - Correction Markers

    /// Common phrases that indicate the speaker is correcting themselves
    private let correctionMarkers = [
        "oh no",
        "oh wait",
        "no wait",
        "wait",
        "actually",
        "I mean",
        "sorry",
        "correction",
        "rather",
        "let me rephrase",
        "I meant to say",
        "no sorry",
        "that's wrong"
    ]

    // MARK: - Public Methods

    /// Process text to remove self-corrections
    /// - Parameter text: The raw transcribed text
    /// - Returns: Text with self-corrections removed
    func process(_ text: String) -> String {
        var processed = text

        // Try to detect and remove corrections
        for marker in correctionMarkers.sorted(by: { $0.count > $1.count }) {
            processed = removeCorrectionWithMarker(processed, marker: marker)
        }

        return processed
    }

    // MARK: - Private Methods

    /// Remove corrections based on a specific marker
    private func removeCorrectionWithMarker(_ text: String, marker: String) -> String {
        let lowercased = text.lowercased()

        // Find all occurrences of the marker
        guard let range = lowercased.range(of: marker) else {
            return text
        }

        // Get the position of the marker
        let markerStart = text.distance(from: text.startIndex, to: range.lowerBound)

        // Find where to cut before the marker
        let cutPoint = findCutPoint(text, beforePosition: markerStart)

        // Get text before cut point
        let beforeCut = String(text.prefix(cutPoint))

        // Skip past the marker and any following punctuation/whitespace
        let afterMarkerIndex = range.upperBound
        var correctedTextStart = afterMarkerIndex

        // Skip commas, spaces after the marker
        while correctedTextStart < text.endIndex {
            let char = text[correctedTextStart]
            if char.isWhitespace || char == "," {
                correctedTextStart = text.index(after: correctedTextStart)
            } else {
                break
            }
        }

        let correctedText = String(text[correctedTextStart...])

        // Combine: text before cut + corrected text
        var result = beforeCut.trimmingCharacters(in: .whitespacesAndNewlines)

        // Add space if needed
        if !result.isEmpty && !correctedText.isEmpty {
            // Check if beforeCut ends with punctuation
            if let lastChar = result.last, !CharacterSet.punctuationCharacters.contains(lastChar.unicodeScalars.first!) {
                result += ". "
            } else if result.hasSuffix(".") || result.hasSuffix("!") || result.hasSuffix("?") {
                result += " "
            } else {
                result += " "
            }
        }

        result += correctedText

        return result
    }

    /// Find the appropriate cut point before a correction marker
    /// Looks for sentence boundaries, commas, or clause boundaries
    private func findCutPoint(_ text: String, beforePosition: Int) -> Int {
        // Convert position to String.Index
        let markerIndex = text.index(text.startIndex, offsetBy: beforePosition)

        // Get text before the marker
        let beforeMarker = String(text[..<markerIndex])

        // Strategy: Look backwards for a natural break point
        // Priority: sentence end (. ! ?) > comma > start of text

        // 1. Try to find last sentence ending
        if let lastSentenceEnd = findLastSentenceEnd(beforeMarker) {
            return lastSentenceEnd
        }

        // 2. Try to find last comma (indicating a clause boundary)
        if let lastComma = findLastComma(beforeMarker) {
            return lastComma
        }

        // 3. If no clear boundary, look for last complete phrase
        // Cut at the last "natural" boundary before the marker
        if let lastPhraseBoundary = findLastPhraseBoundary(beforeMarker) {
            return lastPhraseBoundary
        }

        // 4. Default: cut at the beginning (remove everything before)
        return 0
    }

    private func findLastSentenceEnd(_ text: String) -> Int? {
        // Find last occurrence of . ! ? followed by space and capital letter
        let pattern = #"[.!?]\s+[A-Z]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        if let lastMatch = matches.last {
            // Return position after the sentence-ending punctuation
            return lastMatch.range.location + 1
        }

        // Also check for simple sentence end at the end of the string
        if text.hasSuffix(".") || text.hasSuffix("!") || text.hasSuffix("?") {
            return text.count
        }

        return nil
    }

    private func findLastComma(_ text: String) -> Int? {
        // Find last comma
        if let lastCommaIndex = text.lastIndex(of: ",") {
            let position = text.distance(from: text.startIndex, to: lastCommaIndex)
            // Return position after the comma (and any following space)
            return position + 1
        }

        return nil
    }

    private func findLastPhraseBoundary(_ text: String) -> Int? {
        // Look for common phrase boundaries (conjunctions, prepositions)
        let boundaries = [" and ", " but ", " or ", " so ", " because ", " since ", " while ", " when "]

        var latestPosition = -1

        for boundary in boundaries {
            if let range = text.range(of: boundary, options: .backwards) {
                let position = text.distance(from: text.startIndex, to: range.upperBound)
                latestPosition = max(latestPosition, position)
            }
        }

        return latestPosition > 0 ? latestPosition : nil
    }

    // MARK: - Helper Methods

    /// Get detailed information about detected corrections (for logging/debugging)
    func analyzeCorrections(_ text: String) -> [(marker: String, position: Int)] {
        var corrections: [(marker: String, position: Int)] = []
        let lowercased = text.lowercased()

        for marker in correctionMarkers {
            if let range = lowercased.range(of: marker) {
                let position = text.distance(from: text.startIndex, to: range.lowerBound)
                corrections.append((marker: marker, position: position))
            }
        }

        return corrections.sorted { (a, b) in a.position < b.position }
    }
}
