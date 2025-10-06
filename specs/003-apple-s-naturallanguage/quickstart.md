# Quickstart Guide: NaturalLanguage Framework Text Classifier

**Feature**: 003-apple-s-naturallanguage
**Date**: 2025-10-05
**Purpose**: Validate that the text classification feature works end-to-end

## Prerequisites

- BetterVoice app built and running (macOS 12.0+)
- Xcode 14+ for running tests
- Trained TextClassifier.mlmodel in app bundle (see Training Setup below)

## Training Setup (One-Time)

**Note**: This step creates the CoreML model needed for classification.

### 1. Prepare Training Data

Create a CSV file `training_data.csv` with columns: `text,label`

```csv
text,label
"Hey Sarah, are we still on for lunch?",message
"Dear Hiring Manager, I am writing to express...",email
"The quarterly report shows a 15% increase...",document
"Just shipped our new feature! 🚀",social
"function calculateTotal(items) { return items.reduce(...) }",code
"weather in San Francisco",search
```

**Required**: 500-1000 examples per category (3000-6000 total rows)

### 2. Train Model with CreateML

```swift
// File: TrainingUtility/train_classifier.swift
import CreateML
import Foundation

let data = try MLDataTable(contentsOf: URL(fileURLWithPath: "training_data.csv"))
let (trainingData, validationData) = data.randomSplit(by: 0.8)

let classifier = try MLTextClassifier(
    trainingData: trainingData,
    textColumn: "text",
    labelColumn: "label"
)

let evaluationMetrics = classifier.evaluation(on: validationData)
print("Accuracy: \(evaluationMetrics.classificationError)")

try classifier.write(to: URL(fileURLWithPath: "TextClassifier.mlmodel"))
```

**Run**:
```bash
swift train_classifier.swift
```

**Expected**: `TextClassifier.mlmodel` file created with >80% validation accuracy

### 3. Add Model to App Bundle

1. Drag `TextClassifier.mlmodel` into Xcode project
2. Target: BetterVoice (main app target)
3. Location: `BetterVoice/Resources/Models/`
4. Ensure "Copy items if needed" is checked

**Verify**: Build succeeds, model appears in app bundle

---

## Running the Feature

### Scenario 1: Classify a Casual Message

**Steps**:
1. Launch BetterVoice app
2. Start voice recording
3. Dictate: "Hey Sarah comma are we still on for lunch today question mark"
4. Stop recording

**Expected Result**:
- Transcription appears: "Hey Sarah, are we still on for lunch today?"
- Classification: `.message`
- Text enhancement applies casual formatting (lowercase "hey", emoji support, etc.)

**Validation**:
```swift
// In TextClassificationServiceTests.swift
func testScenario1_casualMessage() async throws {
    let text = "Hey Sarah, are we still on for lunch today?"
    let result = try await service.classify(text)
    XCTAssertEqual(result.category, .message)
}
```

---

### Scenario 2: Classify a Formal Email

**Steps**:
1. Dictate: "Dear hiring manager comma I am writing to express my interest in the software engineer position period"
2. Stop recording

**Expected Result**:
- Transcription: "Dear hiring manager, I am writing to express my interest in the software engineer position."
- Classification: `.email` or `.document`
- Text enhancement applies formal formatting (proper capitalization, professional tone)

**Validation**:
```swift
func testScenario2_formalEmail() async throws {
    let text = "Dear hiring manager, I am writing to express my interest in the position."
    let result = try await service.classify(text)
    XCTAssert([.email, .document].contains(result.category))
}
```

---

### Scenario 3: Classify Code Snippet

**Steps**:
1. Dictate: "function calculate total open paren items close paren open brace return items dot reduce"
2. Stop recording

**Expected Result**:
- Transcription: "function calculateTotal(items) { return items.reduce"
- Classification: `.code`
- Text enhancement preserves technical formatting (monospace, no autocorrect)

**Validation**:
```swift
func testScenario3_codeSnippet() async throws {
    let text = "function calculateTotal(items) { return items.reduce((sum, item) => sum + item.price, 0) }"
    let result = try await service.classify(text)
    XCTAssertEqual(result.category, .code)
}
```

---

### Scenario 4: Classify Social Media Post

**Steps**:
1. Dictate: "Just shipped our new feature exclamation love seeing users respond"
2. Stop recording

**Expected Result**:
- Transcription: "Just shipped our new feature! Love seeing users respond"
- Classification: `.social`
- Text enhancement applies social formatting (emoji insertion, hashtag support)

**Validation**:
```swift
func testScenario4_socialPost() async throws {
    let text = "Just shipped our new feature! Love seeing users respond"
    let result = try await service.classify(text)
    XCTAssertEqual(result.category, .social)
}
```

---

### Scenario 5: Classify Search Query

**Steps**:
1. Dictate: "weather in San Francisco"
2. Stop recording

**Expected Result**:
- Transcription: "weather in San Francisco"
- Classification: `.search`
- Text enhancement applies query formatting (no punctuation, lowercase)

**Validation**:
```swift
func testScenario5_searchQuery() async throws {
    let text = "weather in San Francisco"
    let result = try await service.classify(text)
    XCTAssertEqual(result.category, .search)
}
```

---

### Scenario 6: Mixed Signals (Dominant Characteristics)

**Steps**:
1. Dictate: "Hey comma just wanted to follow up on the quarterly performance review and discuss the metrics we reviewed in our last meeting period"
2. Stop recording

**Expected Result**:
- Transcription: "Hey, just wanted to follow up on the quarterly performance review and discuss the metrics we reviewed in our last meeting."
- Classification: `.message` or `.email` (based on dominant characteristics)
- Dominant analysis: More formal terms ("quarterly performance review", "metrics") vs casual opening ("Hey")
- Result depends on feature frequency

**Validation**:
```swift
func testScenario6_mixedSignals() async throws {
    let text = "Hey, just wanted to follow up on the quarterly performance review and discuss the metrics."
    let result = try await service.classify(text)
    // Should be message or email based on dominant characteristics
    XCTAssert([.message, .email].contains(result.category))
}
```

---

## Performance Validation

### Latency Test

**Test**:
```swift
func testPerformance_classification_under10ms() async throws {
    let text = String(repeating: "This is a test sentence. ", count: 50) // ~500 words
    let startTime = Date()
    let _ = try await service.classify(text)
    let latency = Date().timeIntervalSince(startTime) * 1000 // Convert to ms
    XCTAssertLessThan(latency, 10.0, "Classification took \(latency)ms")
}
```

**Expected**: <10ms on MacBook Air M1

### Memory Test

**Test**:
```swift
func testMemory_classificationService_under10MB() throws {
    let startMemory = getMemoryUsage()
    let service = TextClassificationService()
    _ = try await service.classify("Test text")
    let endMemory = getMemoryUsage()
    let delta = endMemory - startMemory
    XCTAssertLessThan(delta, 10_000_000, "Memory delta: \(delta) bytes")
}
```

**Expected**: <10MB overhead

---

## Database Verification

### Check Logging

**Test**:
```swift
func testLogging_classification_persistsToDatabase() async throws {
    let text = "Test message"
    let _ = try await service.classify(text)

    // Wait for async logging
    try await Task.sleep(nanoseconds: 200_000_000) // 200ms

    // Query database
    let logs = try dbQueue.read { db in
        try ClassificationLog
            .order(Column("timestamp").desc)
            .limit(1)
            .fetchAll(db)
    }

    XCTAssertEqual(logs.first?.text, text)
    XCTAssertEqual(logs.first?.category, "message")
}
```

**Expected**: Log entry created within 200ms

---

## Troubleshooting

### Model Not Loading

**Symptom**: `ClassificationError.modelNotLoaded` thrown

**Fix**:
1. Verify `TextClassifier.mlmodel` exists in app bundle
2. Check Xcode build settings: Target Membership includes model
3. Rebuild app

### Low Accuracy

**Symptom**: Classifications frequently incorrect (< 80%)

**Fix**:
1. Review training data quality (balanced, clean labels)
2. Increase training examples (aim for 1000+ per category)
3. Retrain model with CreateML
4. Validate on holdout test set

### Performance Degradation

**Symptom**: Classification takes >10ms

**Fix**:
1. Check model size (<5MB recommended)
2. Reduce vocabulary size during training
3. Profile with Instruments (Time Profiler)
4. Ensure model is cached (lazy loading working)

---

## Success Criteria

- [ ] All 6 scenarios pass validation tests
- [ ] Performance test shows <10ms latency
- [ ] Memory test shows <10MB overhead
- [ ] Database logging test confirms persistence
- [ ] Integration with TextEnhancementService working
- [ ] App runs without crashes or errors

---

## Next Steps

After quickstart validation:
1. Run full integration test suite
2. Test with real-world transcription examples
3. Collect initial accuracy metrics
4. Plan model retraining workflow (future iteration)
