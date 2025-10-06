# Service Contract: TextClassificationService

**Feature**: 003-apple-s-naturallanguage
**Date**: 2025-10-05
**Type**: Swift Service API

## Overview
TextClassificationService provides the primary public API for classifying text into one of six content categories using on-device machine learning.

## Interface

### Primary Method

```swift
func classify(_ text: String) async throws -> TextClassification
```

**Purpose**: Classify input text into a content category

**Parameters**:
- `text: String` - The text to classify (transcribed content)

**Returns**:
- `TextClassification` - Classification result containing category, timestamp, and text sample

**Throws**:
- `ClassificationError.emptyText` - When input text is empty or whitespace-only
- `ClassificationError.modelNotLoaded` - When CoreML model fails to load
- `ClassificationError.inferenceFailure` - When prediction fails

**Performance**:
- Latency: <10ms for typical input (100-500 words)
- Thread-safe: Can be called concurrently from multiple threads
- Async: Runs inference on background queue, returns on caller's queue

**Examples**:

```swift
// Success case
let text = "Hey Sarah, are we still on for lunch today?"
let result = try await classificationService.classify(text)
assert(result.category == .message)

// Formal document case
let text = "Dear hiring manager, I am writing to express my interest..."
let result = try await classificationService.classify(text)
assert(result.category == .email || result.category == .document)

// Code snippet case
let text = "function calculateTotal(items) { return items.reduce(...) }"
let result = try await classificationService.classify(text)
assert(result.category == .code)
```

**Contract Constraints**:
1. MUST return one of 6 valid categories (email/message/document/social/code/search)
2. MUST complete within 10ms for text <1000 words (p95)
3. MUST NOT return nil or optional - always returns definitive classification
4. MUST log classification result asynchronously (fire-and-forget)
5. MUST be deterministic for same input text (given same model version)

---

## Supporting Types

### TextClassification (Return Type)

```swift
struct TextClassification {
    let category: DocumentType
    let timestamp: Date
    let textSample: String // First 100 chars
}
```

### DocumentType (Category Enum)

```swift
enum DocumentType: String, Codable {
    case email
    case message
    case document
    case social
    case code
    case search
}
```

### ClassificationError (Error Type)

```swift
enum ClassificationError: Error {
    case emptyText
    case modelNotLoaded
    case inferenceFailure(underlying: Error)
}
```

---

## Behavioral Contracts

### BC-1: Empty/Whitespace Input
**Given**: Input text is empty or contains only whitespace
**When**: `classify()` is called
**Then**: Throws `ClassificationError.emptyText`

### BC-2: Model Loading Failure
**Given**: CoreML model file is missing or corrupt
**When**: First call to `classify()`
**Then**: Throws `ClassificationError.modelNotLoaded`

### BC-3: Mixed Formality Signals
**Given**: Input contains conflicting formality markers (e.g., "Hey" + formal structure)
**When**: `classify()` is called
**Then**: Returns category based on dominant characteristics (most frequent signals)

### BC-4: Very Short Input (1-3 words)
**Given**: Input is "weather in Boston"
**When**: `classify()` is called
**Then**: Returns `.search` based on available features (no error, no "uncertain" state)

### BC-5: Concurrent Requests
**Given**: Multiple concurrent calls to `classify()` with different texts
**When**: All requests in flight simultaneously
**Then**: All complete successfully without race conditions or deadlocks

### BC-6: Logging Guarantee
**Given**: Successful classification
**When**: Method returns TextClassification
**Then**: Classification is logged to database asynchronously (logged within 100ms)

### BC-7: Performance Guarantee
**Given**: Input text of 500 words
**When**: `classify()` called on MacBook Air M1 (min spec)
**Then**: Completes within 10ms (p95 latency)

---

## Integration Points

### Callers
- **TextEnhancementService**: Calls classify() after transcription completes
- **AppState**: May call during initialization for testing/warmup
- **Unit Tests**: Direct invocation with test fixtures

### Dependencies
- **ClassificationModelManager**: Provides loaded NLModel
- **FeatureExtractor**: Extracts TextFeatures from input
- **DominantCharacteristicAnalyzer**: Resolves mixed signals
- **ClassificationLogger**: Persists results asynchronously

### Side Effects
- Loads CoreML model on first invocation (lazy init)
- Logs classification to database (async, fire-and-forget)
- No network I/O, no file I/O beyond model loading

---

## Test Requirements

### Contract Tests (Must Pass Before Implementation)

```swift
// Test file: TextClassificationServiceContractTests.swift

func testClassify_validMessage_returnsMessageCategory() async throws
func testClassify_validEmail_returnsEmailOrDocumentCategory() async throws
func testClassify_codeSnippet_returnsCodeCategory() async throws
func testClassify_socialPost_returnsSocialCategory() async throws
func testClassify_searchQuery_returnsSearchCategory() async throws
func testClassify_formalDocument_returnsDocumentCategory() async throws
func testClassify_emptyString_throwsEmptyTextError() async throws
func testClassify_whitespaceOnly_throwsEmptyTextError() async throws
func testClassify_mixedSignals_returnsDominantCategory() async throws
func testClassify_shortInput_returnsValidCategory() async throws
func testClassify_performance_completesUnder10ms() async throws
func testClassify_concurrent_handlesMultipleRequests() async throws
```

### Success Criteria
- All contract tests MUST fail initially (no implementation)
- All contract tests MUST pass after implementation
- No additional tests required beyond contract coverage

---

## Versioning

**Current Version**: 1.0.0 (MVP)

**Future Compatibility**:
- Adding new categories: Breaking change (requires enum update)
- Performance improvements: Non-breaking
- Model retraining: Non-breaking (if same categories maintained)
- Confidence score addition: Breaking change (changes return type)

---

## Non-Functional Requirements

### Performance
- **Latency**: <10ms p95 for text <1000 words
- **Throughput**: 100+ classifications/second (if needed)
- **Memory**: <10MB overhead for service + loaded model

### Reliability
- **Error handling**: All errors thrown explicitly (no silent failures)
- **Thread safety**: Fully thread-safe, supports concurrent access
- **Resource cleanup**: No leaks, model cached for app lifetime

### Observability
- **Logging**: All classifications logged with timestamp and category
- **Metrics**: Latency measurable via test instrumentation
- **Debugging**: textSample in return value aids debugging

---

## Change Log

**v1.0.0 (2025-10-05)**: Initial contract definition for MVP
