#!/usr/bin/env swift

//
//  train_classifier.swift
//  CreateML training script for text classification
//
//  Trains a CoreML text classifier from CSV data
//

import Foundation
import CreateML

func trainClassifier() {
    print("🚀 Starting text classifier training...")

    // Load training data
    let dataURL = URL(fileURLWithPath: "training_data.csv")

    guard FileManager.default.fileExists(atPath: dataURL.path) else {
        print("❌ Error: training_data.csv not found")
        print("   Run generate_training_data.swift first")
        return
    }

    do {
        // Load data table
        print("📊 Loading training data from CSV...")
        let data = try MLDataTable(contentsOf: dataURL)
        print("   Loaded \(data.rows.count) examples")

        // Split into training and validation sets (80/20)
        let (trainingData, validationData) = data.randomSplit(by: 0.8, seed: 42)
        print("   Training set: \(trainingData.rows.count) examples")
        print("   Validation set: \(validationData.rows.count) examples")

        // Create text classifier
        print("\n🧠 Training text classifier...")
        let classifier = try MLTextClassifier(
            trainingData: trainingData,
            textColumn: "text",
            labelColumn: "label"
        )

        // Evaluate on validation set
        print("\n📈 Evaluating model performance...")
        let trainingAccuracy = classifier.trainingMetrics.classificationError
        let validationAccuracy = classifier.validationMetrics.classificationError
        let accuracy = (1.0 - validationAccuracy) * 100

        print("   Training Error: \(String(format: "%.3f", trainingAccuracy))")
        print("   Validation Error: \(String(format: "%.3f", validationAccuracy))")
        print("   Validation Accuracy: \(String(format: "%.1f", accuracy))%")

        // Save model
        let modelURL = URL(fileURLWithPath: "TextClassifier.mlmodel")
        print("\n💾 Saving model to TextClassifier.mlmodel...")
        try classifier.write(to: modelURL)

        print("\n✅ Training complete!")
        print("\n📋 Next steps:")
        print("   1. Add TextClassifier.mlmodel to Xcode project")
        print("   2. Drag into BetterVoice/Resources/Models/ folder")
        print("   3. Ensure Target Membership includes BetterVoice app")
        print("   4. Build and run tests")

        if accuracy < 80.0 {
            print("\n⚠️  Warning: Accuracy is below 80% target")
            print("   Consider adding more training examples")
        }

    } catch {
        print("❌ Error during training: \(error)")
    }
}

// Run
trainClassifier()
