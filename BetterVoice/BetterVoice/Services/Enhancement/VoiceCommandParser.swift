//
//  VoiceCommandParser.swift
//  BetterVoice
//
//  Parses voice command prefixes like "BV" or "Better Voice" to determine
//  formatting instructions and extract content
//

import Foundation

final class VoiceCommandParser {

    static let shared = VoiceCommandParser()

    // MARK: - Configuration

    /// Prefixes that trigger voice command parsing (case-insensitive)
    private let commandPrefixes = [
        "BV",
        "Better Voice",
        "BetterVoice"
    ]

    /// Instruction patterns mapped to document types
    private let instructionPatterns: [InstructionPattern] = [
        // Email patterns
        InstructionPattern(
            pattern: "send an email to",
            documentType: .email,
            extractsRecipient: true,
            metadata: ["format": "email"]
        ),
        InstructionPattern(
            pattern: "sending an email to",
            documentType: .email,
            extractsRecipient: true,
            metadata: ["format": "email"]
        ),
        InstructionPattern(
            pattern: "send an email",
            documentType: .email,
            extractsRecipient: true,
            metadata: ["format": "email"]
        ),
        InstructionPattern(
            pattern: "sending an email",
            documentType: .email,
            extractsRecipient: true,
            metadata: ["format": "email"]
        ),
        InstructionPattern(
            pattern: "write an email to",
            documentType: .email,
            extractsRecipient: true,
            metadata: ["format": "email"]
        ),
        InstructionPattern(
            pattern: "email",
            documentType: .email,
            extractsRecipient: true,
            metadata: ["format": "email"]
        ),
        InstructionPattern(
            pattern: "compose an email to",
            documentType: .email,
            extractsRecipient: true,
            metadata: ["format": "email"]
        ),
        InstructionPattern(
            pattern: "draft an email to",
            documentType: .email,
            extractsRecipient: true,
            metadata: ["format": "email"]
        ),

        // Message/Text patterns
        InstructionPattern(
            pattern: "send a text message to",
            documentType: .message,
            extractsRecipient: true,
            metadata: ["format": "text_message"]
        ),
        InstructionPattern(
            pattern: "text",
            documentType: .message,
            extractsRecipient: true,
            metadata: ["format": "text_message"]
        ),
        InstructionPattern(
            pattern: "message",
            documentType: .message,
            extractsRecipient: true,
            metadata: ["format": "text_message"]
        ),
        InstructionPattern(
            pattern: "send a slack message to",
            documentType: .message,
            extractsRecipient: true,
            metadata: ["format": "slack_message"]
        ),
        InstructionPattern(
            pattern: "slack",
            documentType: .message,
            extractsRecipient: true,
            metadata: ["format": "slack_message"]
        ),

        // Document patterns
        InstructionPattern(
            pattern: "write a memo about",
            documentType: .document,
            extractsRecipient: false,
            metadata: ["format": "memo"]
        ),
        InstructionPattern(
            pattern: "create a memo about",
            documentType: .document,
            extractsRecipient: false,
            metadata: ["format": "memo"]
        ),
        InstructionPattern(
            pattern: "write meeting notes",
            documentType: .document,
            extractsRecipient: false,
            metadata: ["format": "meeting_notes"]
        ),
        InstructionPattern(
            pattern: "create meeting notes",
            documentType: .document,
            extractsRecipient: false,
            metadata: ["format": "meeting_notes"]
        ),
        InstructionPattern(
            pattern: "write a formal letter to",
            documentType: .document,
            extractsRecipient: true,
            metadata: ["format": "formal_letter"]
        ),
        InstructionPattern(
            pattern: "format as bullet points",
            documentType: .document,
            extractsRecipient: false,
            metadata: ["format": "bullet_points"]
        ),
        InstructionPattern(
            pattern: "create a to-do list",
            documentType: .document,
            extractsRecipient: false,
            metadata: ["format": "todo_list"]
        ),
        InstructionPattern(
            pattern: "write meeting minutes",
            documentType: .document,
            extractsRecipient: false,
            metadata: ["format": "meeting_minutes"]
        ),

        // Social media patterns
        InstructionPattern(
            pattern: "draft a tweet",
            documentType: .social,
            extractsRecipient: false,
            metadata: ["format": "tweet", "limit": "280"]
        ),
        InstructionPattern(
            pattern: "write a tweet",
            documentType: .social,
            extractsRecipient: false,
            metadata: ["format": "tweet", "limit": "280"]
        ),
        InstructionPattern(
            pattern: "compose a linkedin post",
            documentType: .social,
            extractsRecipient: false,
            metadata: ["format": "linkedin"]
        ),
        InstructionPattern(
            pattern: "write a linkedin post",
            documentType: .social,
            extractsRecipient: false,
            metadata: ["format": "linkedin"]
        ),
        InstructionPattern(
            pattern: "update linkedin",
            documentType: .social,
            extractsRecipient: false,
            metadata: ["format": "linkedin"]
        ),

        // Search patterns
        InstructionPattern(
            pattern: "search for",
            documentType: .search,
            extractsRecipient: false,
            metadata: ["format": "search_query"]
        ),

        // Capitalization patterns
        InstructionPattern(
            pattern: "capitalise",
            documentType: .unknown,
            extractsRecipient: false,
            metadata: ["format": "capitalise", "mode": "full"]
        ),
        InstructionPattern(
            pattern: "capitalize",
            documentType: .unknown,
            extractsRecipient: false,
            metadata: ["format": "capitalise", "mode": "full"]
        ),
        InstructionPattern(
            pattern: "initial",
            documentType: .unknown,
            extractsRecipient: false,
            metadata: ["format": "capitalise", "mode": "initial"]
        ),
    ]

    private init() {}

    // MARK: - Public Methods

    /// Parses text to detect and extract voice command instructions
    /// - Parameter text: The raw transcribed text
    /// - Returns: A VoiceCommandInstruction if a command is detected, nil otherwise
    func parse(_ text: String) -> VoiceCommandInstruction? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for command prefix
        guard let (prefix, remainder) = detectPrefix(in: trimmed) else {
            return nil
        }

        Logger.shared.info("🎤 Voice command detected: prefix='\(prefix)'")

        // Parse the instruction and content
        guard let (pattern, instruction, content, recipient) = parseInstruction(in: remainder) else {
            Logger.shared.warning("⚠️ Could not parse instruction from: '\(remainder)'")
            return nil
        }

        Logger.shared.info("✅ Parsed instruction: type=\(pattern.documentType.rawValue), recipient=\(recipient ?? "none")")

        return VoiceCommandInstruction(
            prefix: prefix,
            instruction: instruction,
            content: content,
            targetDocumentType: pattern.documentType,
            recipient: recipient,
            metadata: pattern.metadata
        )
    }

    // MARK: - Private Methods

    /// Detects if the text starts with a command prefix
    /// - Returns: The matched prefix and remaining text, or nil if no match
    private func detectPrefix(in text: String) -> (prefix: String, remainder: String)? {
        for prefix in commandPrefixes {
            // Case-insensitive prefix matching
            if text.lowercased().hasPrefix(prefix.lowercased()) {
                let remainder = String(text.dropFirst(prefix.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: ", "))

                // Ensure there's something after the prefix
                guard !remainder.isEmpty else { continue }

                return (prefix, remainder)
            }
        }
        return nil
    }

    /// Parses the instruction and extracts content and recipient
    /// - Returns: The pattern, instruction text, content, and optional recipient
    private func parseInstruction(in text: String) -> (
        pattern: InstructionPattern,
        instruction: String,
        content: String,
        recipient: String?
    )? {
        let lowercased = text.lowercased()

        // Try to match instruction patterns
        for pattern in instructionPatterns {
            if lowercased.hasPrefix(pattern.pattern.lowercased()) {
                let afterPattern = String(text.dropFirst(pattern.pattern.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: ", "))

                // Extract recipient if the pattern expects one
                var recipient: String?
                var content = afterPattern

                if pattern.extractsRecipient {
                    (recipient, content) = extractRecipient(from: afterPattern)
                }

                return (
                    pattern: pattern,
                    instruction: pattern.pattern,
                    content: content,
                    recipient: recipient
                )
            }
        }

        return nil
    }

    /// Extracts recipient name from text (looks for name before period, comma, or greeting)
    /// - Returns: The recipient name and remaining content
    private func extractRecipient(from text: String) -> (recipient: String?, content: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strategy 1: Try to find the first sentence boundary (. or !)
        if let range = trimmed.range(of: #"[.!]"#, options: .regularExpression) {
            let recipient = String(trimmed[..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let content = String(trimmed[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !recipient.isEmpty && !content.isEmpty {
                return (recipient, content)
            }
        }

        // Strategy 2: Look for greeting patterns (Hi, Hello, Dear)
        let greetingPatterns = ["Hi ", "Hello ", "Dear ", "Hey "]
        for pattern in greetingPatterns {
            if let greetingRange = trimmed.range(of: pattern, options: .caseInsensitive) {
                // Everything before the greeting is the recipient
                let recipient = String(trimmed[..<greetingRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let content = String(trimmed[greetingRange.lowerBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !recipient.isEmpty && !content.isEmpty {
                    return (recipient, content)
                }
            }
        }

        // Strategy 3: Take first 1-3 words as recipient if followed by more text
        let words = trimmed.components(separatedBy: .whitespaces)
        if words.count > 3 {
            // Assume first 1-2 words are the name
            let nameWords = words.prefix(min(2, words.count - 2))
            let recipient = nameWords.joined(separator: " ")
            let contentWords = words.dropFirst(nameWords.count)
            let content = contentWords.joined(separator: " ")

            if !content.isEmpty {
                return (recipient, content)
            }
        }

        // Fallback: no clear recipient found, return all as content
        return (nil, trimmed)
    }
}
