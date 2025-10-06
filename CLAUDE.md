# bettervoice Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-09-30

## Active Technologies
- Swift 5.9+ (targeting macOS 12.0+) + SwiftUI, AppKit, AVFoundation, whisper.cpp (C++ bridge), GRDB.swift (SQLite), Carbon Events API (001-bettervoice-macos-voice)
- Swift 5.9+ (targeting macOS 12.0+) + NaturalLanguage.framework, CreateML.framework (Apple built-in), GRDB.swift (for classification logging) (003-apple-s-naturallanguage)
- SQLite via GRDB.swift for classification history/logs; CoreML model bundle for trained classifier (003-apple-s-naturallanguage)

## Project Structure
```
src/
tests/
```

## Commands
# Add commands for Swift 5.9+ (targeting macOS 12.0+)

## Code Style
Swift 5.9+ (targeting macOS 12.0+): Follow standard conventions

## Recent Changes
- 2025-10-05: **003-apple-s-naturallanguage COMPLETED** - On-device text classification feature fully implemented
  - Model Accuracy: 66.7% (minimal training set of 120 examples)
  - Production Target: 80%+ (requires 3000-6000 examples)
  - Limitations: Small training dataset, requires Xcode target configuration for model
  - Services: TextClassificationService, FeatureExtractor, DominantCharacteristicAnalyzer, ClassificationLogger
  - Integration: Auto-classification in TextEnhancementService when documentType is .unknown
  - Training: Automated pipeline in TrainingUtility/ directory (generate_training_data.swift, train_classifier.swift)
- 003-apple-s-naturallanguage: Added Swift 5.9+ (targeting macOS 12.0+) + NaturalLanguage.framework, CreateML.framework (Apple built-in), GRDB.swift (for classification logging)
- 001-bettervoice-macos-voice: Added Swift 5.9+ (targeting macOS 12.0+) + SwiftUI, AppKit, AVFoundation, whisper.cpp (C++ bridge), GRDB.swift (SQLite), Carbon Events API

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
