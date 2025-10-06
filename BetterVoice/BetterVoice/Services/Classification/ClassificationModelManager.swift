//
//  ClassificationModelManager.swift
//  BetterVoice
//
//  Manages CoreML model lifecycle for text classification
//  Singleton pattern with lazy loading and memory caching
//

import Foundation
import NaturalLanguage

/// Manages the lifecycle of the CoreML text classification model
final class ClassificationModelManager {

    // MARK: - Singleton

    static let shared = ClassificationModelManager()

    // MARK: - Properties

    private var model: NLModel?
    private var modelLoadError: Error?
    private let modelQueue = DispatchQueue(label: "com.bettervoice.classification.model", attributes: .concurrent)

    var isLoaded: Bool {
        modelQueue.sync {
            model != nil
        }
    }

    private let modelURL: URL

    // MARK: - Initialization

    private init() {
        // Load model URL from bundle
        guard let url = Bundle.main.url(forResource: "TextClassifier", withExtension: "mlmodel") ??
                        Bundle.main.url(forResource: "TextClassifier", withExtension: "mlmodelc") else {
            // Model not found - will error on first load attempt
            modelURL = URL(fileURLWithPath: "")
            return
        }
        modelURL = url
    }

    // MARK: - Public Interface

    /// Load and return the classification model
    /// - Returns: Loaded NLModel instance
    /// - Throws: ClassificationError.modelNotLoaded if model cannot be loaded
    func loadModel() throws -> NLModel {
        // Check if model already loaded
        if let existingModel = modelQueue.sync(execute: { () -> NLModel? in
            if let model = model {
                return model
            }
            return nil
        }) {
            return existingModel
        }

        // Load model with write barrier for thread safety
        return try modelQueue.sync(flags: .barrier) { () -> NLModel in
            // Double-check in case another thread loaded while waiting
            if let model = model {
                return model
            }

            // Check if model URL is valid
            guard !modelURL.path.isEmpty else {
                let error = ClassificationError.modelNotLoaded
                modelLoadError = error
                throw error
            }

            // Attempt to load model
            do {
                let loadedModel = try NLModel(contentsOf: modelURL)
                model = loadedModel
                return loadedModel
            } catch {
                let classificationError = ClassificationError.modelNotLoaded
                modelLoadError = classificationError
                throw classificationError
            }
        }
    }

    /// Get currently loaded model (if any)
    /// - Returns: Optional NLModel instance
    func getLoadedModel() -> NLModel? {
        modelQueue.sync {
            model
        }
    }

    /// Unload model from memory (for testing or memory management)
    func unloadModel() {
        modelQueue.sync(flags: .barrier) {
            model = nil
            modelLoadError = nil
        }
    }
}
