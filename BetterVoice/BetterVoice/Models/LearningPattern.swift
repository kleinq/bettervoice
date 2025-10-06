//
//  LearningPattern.swift
//  BetterVoice
//
//  Model representing learned user editing patterns
//  Stored in SQLite via GRDB
//

import Foundation
import GRDB

struct LearningPattern: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: Int64?
    let documentType: DocumentType
    let originalText: String
    let editedText: String
    var frequency: Int
    var lastSeen: Date
    var confidence: Double

    // Default initializer
    init(
        id: Int64? = nil,
        documentType: DocumentType,
        originalText: String,
        editedText: String,
        frequency: Int = 1,
        lastSeen: Date = Date(),
        confidence: Double = 1.0
    ) {
        self.id = id
        self.documentType = documentType
        self.originalText = originalText
        self.editedText = editedText
        self.frequency = frequency
        self.lastSeen = lastSeen
        self.confidence = confidence
    }

    // GRDB table name
    static let databaseTableName = "learning_patterns"

    // Computed property for trust threshold
    var isTrusted: Bool {
        return confidence >= 0.7
    }

    // Computed property for significant edit detection
    var isSignificantEdit: Bool {
        guard !originalText.isEmpty else { return false }
        let changeRatio = Double(abs(editedText.count - originalText.count)) / Double(originalText.count)
        return changeRatio >= 0.1
    }

    // Update confidence based on frequency
    mutating func updateConfidence() {
        // Logarithmic confidence growth capped at 1.0
        confidence = min(1.0, log10(Double(frequency) + 1) / log10(11)) // 10 repetitions = 1.0 confidence
    }
}
