//
//  VoiceCommandInstruction.swift
//  BetterVoice
//
//  Voice command instruction model for prefix-based formatting
//

import Foundation

/// Represents a parsed voice command instruction
struct VoiceCommandInstruction {
    /// The detected command prefix ("BV" or "Better Voice")
    let prefix: String

    /// The instruction type (e.g., "write an email", "send a text message")
    let instruction: String

    /// The actual content to be formatted
    let content: String

    /// The document type determined by the instruction
    let targetDocumentType: DocumentType

    /// The recipient if specified in the instruction
    let recipient: String?

    /// Additional metadata from instruction parsing
    let metadata: [String: String]

    init(
        prefix: String,
        instruction: String,
        content: String,
        targetDocumentType: DocumentType,
        recipient: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.prefix = prefix
        self.instruction = instruction
        self.content = content
        self.targetDocumentType = targetDocumentType
        self.recipient = recipient
        self.metadata = metadata
    }
}

/// Instruction pattern for matching voice commands
struct InstructionPattern {
    let pattern: String
    let documentType: DocumentType
    let extractsRecipient: Bool
    let metadata: [String: String]

    init(
        pattern: String,
        documentType: DocumentType,
        extractsRecipient: Bool = false,
        metadata: [String: String] = [:]
    ) {
        self.pattern = pattern
        self.documentType = documentType
        self.extractsRecipient = extractsRecipient
        self.metadata = metadata
    }
}
