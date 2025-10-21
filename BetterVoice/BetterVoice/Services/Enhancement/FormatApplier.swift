//
//  FormatApplier.swift
//  BetterVoice
//
//  Document-type-specific text formatting
//

import Foundation

final class FormatApplier {

    // MARK: - Singleton

    static let shared = FormatApplier()
    private init() {}

    // MARK: - Public Methods

    func apply(to text: String, documentType: DocumentType, recipient: String? = nil, metadata: [String: String] = [:]) -> (formattedText: String, changes: [String]) {
        switch documentType {
        case .email:
            return formatEmail(text, recipient: recipient)
        case .message:
            return formatMessage(text, recipient: recipient)
        case .document:
            return formatDocument(text, metadata: metadata)
        case .social:
            return formatSocial(text, metadata: metadata)
        case .code:
            return formatCode(text)
        case .searchQuery, .search:
            return formatSearchQuery(text)
        case .unknown:
            return formatGeneric(text)
        }
    }

    // MARK: - Email Formatting

    private func formatEmail(_ text: String, recipient: String? = nil) -> (String, [String]) {
        var formatted = text
        var changes: [String] = []

        // Capitalize first letter
        if let firstChar = formatted.first, firstChar.isLowercase {
            formatted = formatted.prefix(1).uppercased() + formatted.dropFirst()
            changes.append("Capitalized first letter")
        }

        // Detect and capitalize names (simple heuristic)
        formatted = capitalizeProbableNames(formatted)

        // Add greeting if missing
        if !hasGreeting(formatted) {
            formatted = addGreeting(formatted, recipient: recipient)
            changes.append("Added greeting\(recipient != nil ? " with recipient" : "")")
        }

        // Break into paragraphs
        formatted = addParagraphs(formatted)
        changes.append("Added paragraph breaks")

        // Add closing if missing and text is long enough
        if formatted.count > 50 && !hasClosing(formatted) {
            formatted = addClosing(formatted)
            changes.append("Added closing")
        }

        // Ensure proper punctuation
        formatted = addPunctuation(formatted)
        changes.append("Added punctuation")

        return (formatted, changes)
    }

    // MARK: - Message Formatting

    private func formatMessage(_ text: String, recipient: String? = nil) -> (String, [String]) {
        var formatted = text
        var changes: [String] = []

        // Add recipient prefix for text messages if specified
        if let recipient = recipient, !formatted.lowercased().hasPrefix("hi ") {
            formatted = "Hi \(recipient), " + formatted
            changes.append("Added recipient greeting")
        }

        // Capitalize first letter
        if let firstChar = formatted.first, firstChar.isLowercase {
            formatted = formatted.prefix(1).uppercased() + formatted.dropFirst()
            changes.append("Capitalized first letter")
        }

        // Add minimal punctuation (end of message only)
        if !formatted.hasSuffix(".") && !formatted.hasSuffix("!") && !formatted.hasSuffix("?") {
            // Determine if question
            if formatted.lowercased().contains("can you") ||
               formatted.lowercased().contains("could you") ||
               formatted.lowercased().hasPrefix("what") ||
               formatted.lowercased().hasPrefix("when") ||
               formatted.lowercased().hasPrefix("where") ||
               formatted.lowercased().hasPrefix("how") {
                formatted += "?"
            } else {
                formatted += "."
            }
            changes.append("Added end punctuation")
        }

        return (formatted, changes)
    }

    // MARK: - Document Formatting

    private func formatDocument(_ text: String, metadata: [String: String] = [:]) -> (String, [String]) {
        var formatted = text
        var changes: [String] = []

        // Check for special formatting instructions
        if let format = metadata["format"] {
            switch format {
            case "bullet_points":
                formatted = formatAsBulletPoints(text)
                changes.append("Formatted as bullet points")
                return (formatted, changes)
            case "todo_list":
                formatted = formatAsTodoList(text)
                changes.append("Formatted as to-do list")
                return (formatted, changes)
            case "memo":
                formatted = formatAsMemo(text)
                changes.append("Formatted as memo")
                return (formatted, changes)
            default:
                break
            }
        }

        // Split into sentences
        let sentences = splitIntoSentences(formatted)

        // Capitalize each sentence
        let capitalizedSentences = sentences.map { sentence -> String in
            guard let first = sentence.first else { return sentence }
            return first.uppercased() + sentence.dropFirst()
        }

        // Detect lists (lines starting with numbers or bullets)
        formatted = formatLists(capitalizedSentences.joined(separator: " "))
        changes.append("Formatted lists")

        // Add paragraph breaks for longer content
        if formatted.count > 200 {
            formatted = addParagraphs(formatted)
            changes.append("Added paragraph breaks")
        }

        // Ensure proper punctuation
        formatted = addPunctuation(formatted)
        changes.append("Added punctuation")

        return (formatted, changes)
    }

    // MARK: - Social Media Formatting

    private func formatSocial(_ text: String, metadata: [String: String] = [:]) -> (String, [String]) {
        var formatted = text
        var changes: [String] = []

        // Capitalize first letter
        if let firstChar = formatted.first, firstChar.isLowercase {
            formatted = formatted.prefix(1).uppercased() + formatted.dropFirst()
            changes.append("Capitalized first letter")
        }

        // Check for explicit social media format (from voice command)
        if let format = metadata["format"] {
            // Tweet: enforce character limit
            if format == "tweet", let limitStr = metadata["limit"], let limit = Int(limitStr) {
                if formatted.count > limit {
                    formatted = String(formatted.prefix(limit - 3)) + "..."
                    changes.append("Trimmed to \(limit) characters for Twitter")
                }
            }
            // LinkedIn or other social: trim to reasonable length
            else if format == "linkedin" {
                let words = formatted.components(separatedBy: .whitespaces)
                if words.count > 150 {
                    formatted = words.prefix(150).joined(separator: " ") + "..."
                    changes.append("Trimmed for LinkedIn length")
                }
            }
        } else {
            // Auto-classified as social (no explicit voice command)
            // Only trim if text is already short (likely meant to be a post)
            // Don't trim long-form content that was mis-classified
            let words = formatted.components(separatedBy: .whitespaces)

            // Only trim if original is < 100 words AND > 40 words
            // (If it's already very long, it's probably not meant to be social media)
            if words.count > 40 && words.count < 100 {
                formatted = words.prefix(40).joined(separator: " ") + "..."
                changes.append("Trimmed for social media length")
            }
            // If > 100 words, it's likely mis-classified - don't trim
        }

        // Add minimal punctuation
        if !formatted.hasSuffix(".") && !formatted.hasSuffix("!") && !formatted.hasSuffix("?") && !formatted.hasSuffix("...") {
            formatted += "."
            changes.append("Added end punctuation")
        }

        return (formatted, changes)
    }

    // MARK: - Code/Technical Formatting

    private func formatCode(_ text: String) -> (String, [String]) {
        var formatted = text
        var changes: [String] = []

        // Capitalize first letter
        if let firstChar = formatted.first, firstChar.isLowercase {
            formatted = formatted.prefix(1).uppercased() + formatted.dropFirst()
            changes.append("Capitalized first letter")
        }

        // Keep formatting minimal for code comments
        if !formatted.hasSuffix(".") && !formatted.hasSuffix("!") && !formatted.hasSuffix("?") {
            formatted += "."
            changes.append("Added end punctuation")
        }

        return (formatted, changes)
    }

    // MARK: - Search Query Formatting

    private func formatSearchQuery(_ text: String) -> (String, [String]) {
        var formatted = text
        var changes: [String] = []

        // Extract keywords (remove unnecessary words)
        let stopWords = ["the", "a", "an", "is", "are", "was", "were", "to", "for", "of", "in", "on"]
        var words = formatted.lowercased().components(separatedBy: .whitespacesAndNewlines)

        words = words.filter { !stopWords.contains($0) && !$0.isEmpty }

        formatted = words.joined(separator: " ")
        changes.append("Extracted keywords")

        // Remove punctuation
        formatted = formatted.replacingOccurrences(of: "[.,!?]", with: "", options: .regularExpression)

        // Keep concise (max 10 words)
        let queryWords = formatted.components(separatedBy: .whitespaces)
        if queryWords.count > 10 {
            formatted = queryWords.prefix(10).joined(separator: " ")
            changes.append("Trimmed to 10 words")
        }

        return (formatted, changes)
    }

    // MARK: - Generic Formatting

    private func formatGeneric(_ text: String) -> (String, [String]) {
        var formatted = text
        var changes: [String] = []

        // Capitalize first letter
        if let firstChar = formatted.first, firstChar.isLowercase {
            formatted = formatted.prefix(1).uppercased() + formatted.dropFirst()
            changes.append("Capitalized first letter")
        }

        // Add basic punctuation
        formatted = addPunctuation(formatted)
        changes.append("Added punctuation")

        return (formatted, changes)
    }

    // MARK: - Helper Methods

    private func hasGreeting(_ text: String) -> Bool {
        let greetings = ["hi", "hello", "hey", "dear", "good morning", "good afternoon", "good evening"]
        let lowerText = text.lowercased()
        return greetings.contains { lowerText.hasPrefix($0) }
    }

    private func addGreeting(_ text: String, recipient: String? = nil) -> String {
        if let recipient = recipient {
            return "Hi \(recipient),\n\n" + text
        }
        return "Hi,\n\n" + text
    }

    private func hasClosing(_ text: String) -> Bool {
        let closings = ["thanks", "thank you", "regards", "sincerely", "best", "cheers"]
        let lowerText = text.lowercased()
        return closings.contains { lowerText.contains($0) }
    }

    private func addClosing(_ text: String) -> String {
        return text + "\n\nThanks"
    }

    private func capitalizeProbableNames(_ text: String) -> String {
        // Simple heuristic: capitalize words after "Hi", "Dear", "Hello"
        var result = text
        let namePatterns = ["hi ", "dear ", "hello ", "hey "]

        for pattern in namePatterns {
            if let range = result.range(of: pattern, options: .caseInsensitive) {
                let afterGreeting = result.index(after: range.upperBound)
                if afterGreeting < result.endIndex {
                    // Find the next word
                    let remaining = result[afterGreeting...]
                    if let wordEnd = remaining.firstIndex(where: { $0.isWhitespace || $0.isPunctuation }) {
                        let word = String(remaining[..<wordEnd])
                        let capitalizedWord = word.prefix(1).uppercased() + word.dropFirst()
                        result = result.replacingOccurrences(of: word, with: capitalizedWord)
                    }
                }
            }
        }

        return result
    }

    private func addParagraphs(_ text: String) -> String {
        let sentences = splitIntoSentences(text)
        var paragraphs: [String] = []
        var currentParagraph: [String] = []

        for sentence in sentences {
            currentParagraph.append(sentence)

            // Start new paragraph after 2-3 sentences
            if currentParagraph.count >= 3 {
                paragraphs.append(currentParagraph.joined(separator: " "))
                currentParagraph = []
            }
        }

        // Add remaining sentences
        if !currentParagraph.isEmpty {
            paragraphs.append(currentParagraph.joined(separator: " "))
        }

        return paragraphs.joined(separator: "\n\n")
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        // Simple sentence splitting on periods, question marks, exclamation marks
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return sentences
    }

    private func addPunctuation(_ text: String) -> String {
        let sentences = splitIntoSentences(text)

        let punctuatedSentences = sentences.map { sentence -> String in
            var s = sentence.trimmingCharacters(in: .whitespacesAndNewlines)

            // Add period if no ending punctuation
            if !s.hasSuffix(".") && !s.hasSuffix("!") && !s.hasSuffix("?") {
                s += "."
            }

            return s
        }

        return punctuatedSentences.joined(separator: " ")
    }

    private func formatLists(_ text: String) -> String {
        // Detect potential list items (lines starting with numbers)
        let lines = text.components(separatedBy: "\n")
        var formatted: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // Check if line starts with number
            if let firstChar = trimmed.first, firstChar.isNumber {
                formatted.append(trimmed)
            } else {
                formatted.append(trimmed)
            }
        }

        return formatted.joined(separator: "\n")
    }

    // MARK: - Special Format Helpers

    private func formatAsBulletPoints(_ text: String) -> String {
        let sentences = splitIntoSentences(text)
        let bullets = sentences.map { sentence -> String in
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "" }
            let capitalized = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
            return "• \(capitalized)"
        }
        return bullets.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private func formatAsTodoList(_ text: String) -> String {
        let sentences = splitIntoSentences(text)
        let todos = sentences.map { sentence -> String in
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "" }
            let capitalized = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
            return "☐ \(capitalized)"
        }
        return todos.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private func formatAsMemo(_ text: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateString = dateFormatter.string(from: Date())

        var memo = "MEMO\n"
        memo += "Date: \(dateString)\n\n"

        // Capitalize first letter
        var content = text
        if let firstChar = content.first, firstChar.isLowercase {
            content = content.prefix(1).uppercased() + content.dropFirst()
        }

        // Add paragraphs for longer content
        if content.count > 200 {
            content = addParagraphs(content)
        }

        memo += content

        return memo
    }
}
