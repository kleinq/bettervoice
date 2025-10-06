//
//  TextClassification.swift
//  BetterVoice
//
//  Classification result value type
//  Represents the outcome of text classification
//

import Foundation

struct TextClassification: Codable {
    let category: DocumentType
    let timestamp: Date
    let textSample: String

    init(category: DocumentType, timestamp: Date, textSample: String) {
        self.category = category
        self.timestamp = timestamp
        // Ensure textSample doesn't exceed 100 characters
        self.textSample = String(textSample.prefix(100))
    }

    /// Validation: textSample must not exceed 100 characters
    var isValid: Bool {
        return textSample.count <= 100
    }
}
