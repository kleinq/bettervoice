//
//  ClassificationLogger.swift
//  BetterVoice
//
//  Async logging of classification results to database for future model retraining
//

import Foundation
import GRDB

/// Logs classification results to database asynchronously
final class ClassificationLogger {

    // MARK: - Properties

    private let dbQueue: DatabaseQueue

    // MARK: - Initialization

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - Public Interface

    /// Log classification result to database
    /// - Parameters:
    ///   - classification: The classification result
    ///   - fullText: Complete original text
    ///   - features: Optional extracted features
    /// - Note: Does not throw - errors are logged internally
    func log(
        classification: TextClassification,
        fullText: String,
        features: TextFeatures?
    ) async {
        // Skip logging if text is empty
        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Create log entry
        let logEntry = ClassificationLog(
            id: UUID(),
            text: fullText,
            category: classification.category.classificationCategory,
            timestamp: classification.timestamp,
            textLength: fullText.count,
            extractedFeatures: features.flatMap { serializeFeatures($0) }
        )

        // Persist to database asynchronously
        do {
            try await dbQueue.write { db in
                try logEntry.insert(db)
            }
        } catch {
            // Log error but don't throw - fire-and-forget pattern
            print("[ClassificationLogger] Failed to log classification: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helper Methods

    private func serializeFeatures(_ features: TextFeatures) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        do {
            let jsonData = try encoder.encode(features)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("[ClassificationLogger] Failed to serialize features: \(error.localizedDescription)")
            return nil
        }
    }
}
