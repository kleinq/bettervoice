//
//  ClassificationLog.swift
//  BetterVoice
//
//  GRDB database model for classification history
//  Stores classification results for model retraining
//

import Foundation
import GRDB

struct ClassificationLog: Codable, FetchableRecord, PersistableRecord {
    var id: UUID
    var text: String
    var category: String
    var timestamp: Date
    var textLength: Int
    var extractedFeatures: String?

    init(
        id: UUID = UUID(),
        text: String,
        category: String,
        timestamp: Date = Date(),
        textLength: Int? = nil,
        extractedFeatures: String? = nil
    ) {
        self.id = id
        self.text = text
        self.category = category
        self.timestamp = timestamp
        self.textLength = textLength ?? text.count
        self.extractedFeatures = extractedFeatures
    }

    static let databaseTableName = "classification_log"

    // GRDB will handle UUID automatically via Codable
    // UUIDs are stored as TEXT (UUID string) in SQLite
}
