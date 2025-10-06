//
//  TextClassificationService.swift
//  BetterVoice
//
//  Main classification service that coordinates model inference, feature extraction,
//  dominant characteristic analysis, and logging
//

import Foundation
import NaturalLanguage

/// Primary text classification service
final class TextClassificationService {

    // MARK: - Properties

    private let modelManager: ClassificationModelManager
    private let featureExtractor: FeatureExtractor
    private let analyzer: DominantCharacteristicAnalyzer
    private let logger: ClassificationLogger

    // MARK: - Initialization

    init(
        modelManager: ClassificationModelManager = .shared,
        featureExtractor: FeatureExtractor,
        analyzer: DominantCharacteristicAnalyzer,
        logger: ClassificationLogger
    ) {
        self.modelManager = modelManager
        self.featureExtractor = featureExtractor
        self.analyzer = analyzer
        self.logger = logger
    }

    // MARK: - Public Interface

    /// Classify input text into a content category
    /// - Parameter text: Text to classify
    /// - Returns: TextClassification result with category, timestamp, and sample
    /// - Throws: ClassificationError on validation or model failures
    func classify(_ text: String) async throws -> TextClassification {
        // Validate input
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ClassificationError.emptyText
        }

        // Extract features
        let features = featureExtractor.extract(from: trimmed)

        // Load model and get prediction
        let model = try modelManager.loadModel()
        guard let prediction = model.predictedLabel(for: trimmed) else {
            throw ClassificationError.inferenceFailure(underlying: NSError(
                domain: "com.bettervoice.classification",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Model returned nil prediction"]
            ))
        }

        // Map prediction string to DocumentType
        let mlCategory = mapPredictionToCategory(prediction)

        // Analyze with dominant characteristic analyzer
        let finalCategory = analyzer.analyze(text: trimmed, features: features, mlPrediction: mlCategory)

        // Create classification result
        let classification = TextClassification(
            category: finalCategory,
            timestamp: Date(),
            textSample: String(trimmed.prefix(100))
        )

        // Log asynchronously (fire-and-forget)
        Task.detached(priority: .background) { [logger, features] in
            await logger.log(
                classification: classification,
                fullText: trimmed,
                features: features
            )
        }

        return classification
    }

    // MARK: - Private Helper Methods

    private func mapPredictionToCategory(_ prediction: String) -> DocumentType {
        // Map model prediction string to DocumentType enum
        switch prediction.lowercased() {
        case "email":
            return .email
        case "message":
            return .message
        case "document":
            return .document
        case "social":
            return .social
        case "code":
            return .code
        case "search":
            return .search
        default:
            // Fallback to message for unknown predictions
            print("[TextClassificationService] Unknown prediction '\(prediction)', defaulting to .message")
            return .message
        }
    }
}
