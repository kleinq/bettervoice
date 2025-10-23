//
//  DatabaseManager.swift
//  BetterVoice
//
//  GRDB database manager for SQLite storage
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

        // Migration v1: Create classification_log table
        migrator.registerMigration("createClassificationLog") { db in
            try db.create(table: "classification_log") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("text", .text).notNull()

                // Category with check constraint
                t.column("category", .text).notNull()
                    .check(sql: "category IN ('email', 'message', 'document', 'social', 'code', 'search')")

                t.column("timestamp", .datetime).notNull()
                t.column("textLength", .integer).notNull()
                    .check { $0 > 0 }
                t.column("extractedFeatures", .text)
            }

            // Indexes for classification log queries
            try db.create(index: "idx_classification_log_timestamp", on: "classification_log", columns: ["timestamp"])
            try db.create(index: "idx_classification_log_category", on: "classification_log", columns: ["category"])
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
}
