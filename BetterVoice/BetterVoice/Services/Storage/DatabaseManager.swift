//
//  DatabaseManager.swift
//  BetterVoice
//
//  GRDB database manager for SQLite storage
//  Manages learning patterns table
//

import Foundation
import GRDB

enum DatabaseError: Error {
    case setupFailed(String)
    case migrationFailed(String)
    case queryFailed(String)
}

final class DatabaseManager {
    static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue?
    private let databaseURL: URL

    // Private init for singleton
    private init() {
        // Store database in Application Support
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let appDirectory = appSupport.appendingPathComponent("BetterVoice", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: appDirectory,
            withIntermediateDirectories: true
        )

        databaseURL = appDirectory.appendingPathComponent("bettervoice.db")
    }

    // Initialize database
    func setup() throws {
        do {
            dbQueue = try DatabaseQueue(path: databaseURL.path)
            try migrate()
        } catch {
            throw DatabaseError.setupFailed("Failed to initialize database: \(error.localizedDescription)")
        }
    }

    // Run migrations
    private func migrate() throws {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.setupFailed("Database queue not initialized")
        }

        var migrator = DatabaseMigrator()

        // Migration v1: Create learning_patterns table
        migrator.registerMigration("createLearningPatterns") { db in
            try db.create(table: "learning_patterns") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("documentType", .text).notNull()
                t.column("originalText", .text).notNull()
                t.column("editedText", .text).notNull()
                t.column("frequency", .integer).notNull().defaults(to: 1)
                t.column("lastSeen", .datetime).notNull()
                t.column("confidence", .double).notNull().defaults(to: 1.0)
            }

            // Indexes for fast lookup
            try db.create(index: "idx_learning_patterns_documentType", on: "learning_patterns", columns: ["documentType"])
            try db.create(index: "idx_learning_patterns_originalText", on: "learning_patterns", columns: ["originalText"])
            try db.create(index: "idx_learning_patterns_confidence", on: "learning_patterns", columns: ["confidence"])
        }

        do {
            try migrator.migrate(dbQueue)
        } catch {
            throw DatabaseError.migrationFailed("Migration failed: \(error.localizedDescription)")
        }
    }

    // Get database queue for read/write operations
    func getQueue() throws -> DatabaseQueue {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.setupFailed("Database not initialized. Call setup() first.")
        }
        return dbQueue
    }

    // Save a learning pattern
    func saveLearningPattern(_ pattern: inout LearningPattern) throws {
        let queue = try getQueue()

        try queue.write { db in
            try pattern.save(db)
        }
    }

    // Fetch learning patterns by document type
    func fetchLearningPatterns(
        for documentType: DocumentType,
        minimumConfidence: Double = 0.7
    ) throws -> [LearningPattern] {
        let queue = try getQueue()

        return try queue.read { db in
            try LearningPattern
                .filter(Column("documentType") == documentType.rawValue)
                .filter(Column("confidence") >= minimumConfidence)
                .order(Column("confidence").desc, Column("frequency").desc)
                .fetchAll(db)
        }
    }

    // Find similar pattern by edit distance
    func findSimilarPattern(
        originalText: String,
        documentType: DocumentType,
        threshold: Double = 0.7
    ) throws -> LearningPattern? {
        let queue = try getQueue()

        return try queue.read { db in
            // Fetch all patterns for this document type
            let patterns = try LearningPattern
                .filter(Column("documentType") == documentType.rawValue)
                .filter(Column("confidence") >= threshold)
                .fetchAll(db)

            // Find best match by edit distance
            // In production, this would use more sophisticated similarity
            return patterns.first { pattern in
                pattern.originalText.lowercased() == originalText.lowercased()
            }
        }
    }

    // Update pattern frequency and confidence
    func incrementPatternFrequency(_ patternID: Int64) throws {
        let queue = try getQueue()

        try queue.write { db in
            if var pattern = try LearningPattern.fetchOne(db, key: patternID) {
                pattern.frequency += 1
                pattern.lastSeen = Date()
                pattern.updateConfidence()
                try pattern.update(db)
            }
        }
    }

    // Delete old patterns (cleanup)
    func deleteOldPatterns(olderThan days: Int) throws {
        let queue = try getQueue()
        let cutoffDate = Date().addingTimeInterval(-Double(days * 86400))

        _ = try queue.write { db in
            try LearningPattern
                .filter(Column("lastSeen") < cutoffDate)
                .filter(Column("frequency") < 3) // Keep frequently used patterns
                .deleteAll(db)
        }
    }

    // Get statistics
    func getStatistics() throws -> DatabaseStatistics {
        let queue = try getQueue()

        return try queue.read { db in
            let totalPatterns = try LearningPattern.fetchCount(db)
            let trustedPatterns = try LearningPattern
                .filter(Column("confidence") >= 0.7)
                .fetchCount(db)

            return DatabaseStatistics(
                totalPatterns: totalPatterns,
                trustedPatterns: trustedPatterns,
                databaseSizeBytes: try getDatabaseSize()
            )
        }
    }

    private func getDatabaseSize() throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: databaseURL.path)
        return attributes[.size] as? Int64 ?? 0
    }
}

// Statistics model
struct DatabaseStatistics {
    let totalPatterns: Int
    let trustedPatterns: Int
    let databaseSizeBytes: Int64

    var databaseSizeMB: Double {
        Double(databaseSizeBytes) / 1_048_576.0
    }
}
