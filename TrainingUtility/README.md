# Text Classification Training Utilities

This directory contains tools for training the CoreML text classifier used in BetterVoice.

## Overview

The text classifier categorizes dictated text into 6 types:
- **email**: Formal email communication
- **message**: Casual messaging (Slack, iMessage)
- **document**: Formal documents (reports, essays)
- **social**: Social media posts
- **code**: Programming code snippets
- **search**: Search queries

## Files

- `generate_training_data.swift` - Generates labeled training data CSV
- `train_classifier.swift` - Trains CoreML text classifier model
- `training_data.csv` - Generated training data (120 examples)
- `TextClassifier.mlmodel` - Trained CoreML model

## Quick Start

### 1. Generate Training Data

```bash
swift generate_training_data.swift
```

This creates `training_data.csv` with 120 examples (20 per category).

### 2. Train Model

```bash
swift train_classifier.swift
```

This trains the model and outputs `TextClassifier.mlmodel`.

### 3. Add Model to Xcode

1. Open `BetterVoice.xcodeproj` in Xcode
2. Drag `TextClassifier.mlmodel` into `BetterVoice/Resources/Models/`
3. In file inspector, ensure Target Membership includes "BetterVoice"
4. Build and run the app

## Current Status

**Minimal Training Set (MVP)**
- Training examples: 97 (80% split)
- Validation examples: 23 (20% split)
- Validation accuracy: 66.7%

**Note**: This accuracy is below the 80% target due to the small dataset. For production use, expand the training data to 500-1000 examples per category (3000-6000 total).

## Improving Accuracy

To achieve 80%+ accuracy:

1. **Expand Training Data**
   - Add 400-980 more examples per category
   - Focus on edge cases and ambiguous examples
   - Ensure balanced representation across categories

2. **Example Sources**
   - Real user transcriptions (anonymized)
   - Public datasets (emails, social media, code)
   - Template variations
   - Synthetic data generation

3. **Iterative Training**
   ```bash
   # After adding more examples to generate_training_data.swift
   swift generate_training_data.swift
   swift train_classifier.swift
   ```

4. **Validation**
   - Test on held-out examples
   - Review misclassifications
   - Adjust examples to address weaknesses

## Model Performance

Monitor classification accuracy through:
- Database logs: `classification_log` table
- Integration tests: `ClassificationIntegrationTests.swift`
- Manual testing with real transcriptions

## Troubleshooting

### Model Not Loading in App

**Problem**: `ClassificationError.modelNotLoaded`

**Solution**:
1. Verify model exists at `BetterVoice/Resources/Models/TextClassifier.mlmodel`
2. Check Xcode Target Membership
3. Clean build folder (Cmd+Shift+K)
4. Rebuild app

### Low Accuracy

**Problem**: Classifications frequently incorrect

**Solution**:
1. Review training examples for quality
2. Add more diverse examples
3. Check for mislabeled data
4. Retrain with larger dataset

### Training Fails

**Problem**: Script errors during training

**Solution**:
1. Ensure CreateML framework is available (macOS 12.0+)
2. Check CSV format (text,label columns)
3. Verify no special characters breaking CSV parsing

## Architecture Notes

The classifier uses CreateML's `MLTextClassifier`:
- **Algorithm**: MaxEnt (Maximum Entropy) classifier
- **Features**: Bag-of-words with n-grams
- **Input**: Raw text strings
- **Output**: Category label (email/message/document/social/code/search)
- **Model size**: ~10KB (minimal dataset)

## Future Enhancements

1. **Active Learning**: Use misclassifications to improve dataset
2. **A/B Testing**: Compare model versions
3. **Automated Retraining**: Periodic updates from logged data
4. **Multi-language**: Train separate models per language
5. **Transfer Learning**: Use pre-trained embeddings
