//
//  SemanticDiffer.swift
//  BetterVoice
//
//  Semantic diff engine with intelligent change detection
//  Filters trivial changes and detects cascades
//

import Foundation

// MARK: - Change

struct Change: Equatable {
    let originalTokens: [Token]
    let editedTokens: [Token]
    let position: Int // Position in original token array

    var originalText: String {
        originalTokens.map { $0.text }.joined()
    }

    var editedText: String {
        editedTokens.map { $0.text }.joined()
    }

    var isCaseOnlyChange: Bool {
        originalText.lowercased() == editedText.lowercased()
    }

    var isPunctuationOnly: Bool {
        let origWords = originalTokens.filter { $0.isWord }
        let editWords = editedTokens.filter { $0.isWord }
        return origWords == editWords
    }
}

// MARK: - Semantic Differ

final class SemanticDiffer {

    // MARK: - Singleton

    static let shared = SemanticDiffer()
    private init() {}

    private let tokenizer = TextTokenizer.shared

    // MARK: - Public Methods

    /// Extract semantic changes between two texts
    func extractChanges(from original: String, to edited: String) -> [Change] {
        let originalTokens = tokenizer.tokenize(original)
        let editedTokens = tokenizer.tokenize(edited)

        // Check if content was completely replaced (>80% different words)
        if isCompleteReplacement(originalTokens, editedTokens) {
            Logger.shared.debug("Text completely replaced - rejecting as learning pattern")
            return []
        }

        // Check if same words just reordered
        if sameWordsReordered(originalTokens, editedTokens) {
            Logger.shared.debug("Text reordered but same words - rejecting as rewrite")
            return []
        }

        // Run Myers diff algorithm at token level
        let rawChanges = myersDiff(originalTokens, editedTokens)

        // Filter trivial changes
        let semanticChanges = rawChanges.filter { isSemanticChange($0, in: original) }

        Logger.shared.info("Found \(semanticChanges.count) semantic changes (filtered from \(rawChanges.count) raw)")

        return semanticChanges
    }

    /// Group related changes (cascades)
    func groupCascades(_ changes: [Change]) -> [[Change]] {
        guard !changes.isEmpty else { return [] }

        var groups: [[Change]] = []
        var currentGroup: [Change] = [changes[0]]

        for i in 1..<changes.count {
            let prev = changes[i - 1]
            let current = changes[i]

            // Check if current change is part of cascade:
            // - Position within 3 tokens of previous
            // - (Timing would be checked in EditBuffer, all changes here are from same session)
            let positionDelta = abs(current.position - prev.position)

            if positionDelta <= 3 {
                // Part of cascade
                currentGroup.append(current)
            } else {
                // New independent change
                groups.append(currentGroup)
                currentGroup = [current]
            }
        }

        // Add last group
        groups.append(currentGroup)

        Logger.shared.info("Grouped \(changes.count) changes into \(groups.count) cascades")

        return groups
    }

    // MARK: - Private Methods

    private func isCompleteReplacement(_ original: [Token], _ edited: [Token]) -> Bool {
        let originalWords = Set(original.filter { $0.isWord }.map { $0.text.lowercased() })
        let editedWords = Set(edited.filter { $0.isWord }.map { $0.text.lowercased() })

        guard !originalWords.isEmpty && !editedWords.isEmpty else { return false }

        let commonWords = originalWords.intersection(editedWords)
        let similarityRatio = Double(commonWords.count) / Double(max(originalWords.count, editedWords.count))

        // If less than 20% words in common, consider it a complete replacement
        return similarityRatio < 0.2
    }

    private func sameWordsReordered(_ original: [Token], _ edited: [Token]) -> Bool {
        let originalWords = original.filter { $0.isWord }.map { $0.text.lowercased() }.sorted()
        let editedWords = edited.filter { $0.isWord }.map { $0.text.lowercased() }.sorted()

        // Same words in different order = rewrite, not correction
        return originalWords == editedWords && original.count != edited.count
    }

    private func isSemanticChange(_ change: Change, in fullText: String) -> Bool {
        // Filter 1: Ignore case-only changes at sentence start
        if change.isCaseOnlyChange {
            // Check if at sentence start (position 0 or after ". ")
            let isAtSentenceStart = change.position == 0 ||
                fullText.contains(". \(change.originalText)")

            if isAtSentenceStart {
                Logger.shared.debug("Ignoring case-only change at sentence start: \(change.originalText)")
                return false
            }
        }

        // Filter 2: Ignore punctuation-only changes at end
        if change.isPunctuationOnly {
            // Check if change is at end of text
            let originalIndex = change.originalTokens.first?.range.lowerBound
            if let index = originalIndex, fullText.distance(from: index, to: fullText.endIndex) < 5 {
                Logger.shared.debug("Ignoring punctuation-only change at end")
                return false
            }
        }

        // Filter 3: Ignore very short changes (<3 chars) unless it's a known correction pattern
        let minLength = min(change.originalText.count, change.editedText.count)
        if minLength < 3 && !isKnownShortCorrection(change) {
            Logger.shared.debug("Ignoring short change: \(change.originalText) → \(change.editedText)")
            return false
        }

        return true
    }

    private func isKnownShortCorrection(_ change: Change) -> Bool {
        // Common short corrections: "its" → "it's", "im" → "I'm", etc.
        let commonShortCorrections: [(String, String)] = [
            ("im", "I'm"), ("id", "I'd"), ("ill", "I'll"),
            ("its", "it's"), ("theyre", "they're"), ("youre", "you're")
        ]

        let orig = change.originalText.lowercased()
        let edit = change.editedText.lowercased()

        return commonShortCorrections.contains { $0.0 == orig && $0.1 == edit } ||
               commonShortCorrections.contains { $0.1 == orig && $0.0 == edit }
    }

    // MARK: - Myers Diff Algorithm (Simplified)

    private func myersDiff(_ original: [Token], _ edited: [Token]) -> [Change] {
        var changes: [Change] = []
        var i = 0
        var j = 0

        while i < original.count || j < edited.count {
            // Find matching tokens
            if i < original.count && j < edited.count && original[i] == edited[j] {
                i += 1
                j += 1
                continue
            }

            // Found a difference - collect changed tokens
            var origTokens: [Token] = []
            var editTokens: [Token] = []
            let startPos = i

            // Collect different tokens until we find a match
            var lookAhead = 1
            while i < original.count || j < edited.count {
                // Try to find next matching token within window
                var foundMatch = false

                for offset in 0..<lookAhead {
                    if i + offset < original.count && j + offset < edited.count &&
                       original[i + offset] == edited[j + offset] {
                        foundMatch = true
                        break
                    }
                }

                if foundMatch { break }

                if i < original.count {
                    origTokens.append(original[i])
                    i += 1
                }
                if j < edited.count {
                    editTokens.append(edited[j])
                    j += 1
                }

                lookAhead += 1
                if lookAhead > 5 { break } // Limit window
            }

            if !origTokens.isEmpty || !editTokens.isEmpty {
                changes.append(Change(
                    originalTokens: origTokens,
                    editedTokens: editTokens,
                    position: startPos
                ))
            }
        }

        return changes
    }
}
