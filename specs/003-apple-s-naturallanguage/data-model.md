# Data Model: NaturalLanguage Framework Text Classifier

**Feature**: 003-apple-s-naturallanguage
**Date**: 2025-10-05

## Entities

### 1. TextClassification (Value Type)

**Purpose**: Represents the result of classifying a piece of text

**Fields**:
- `category: DocumentType` - Classified category (email/message/document/social/code/search)
- `timestamp: Date` - When classification occurred
- `textSample: String` - First 100 chars of classified text (for logging/debugging)

**Validation Rules**:
- `category` must be one of the 6 defined DocumentType enum cases
- `timestamp` must not be in the future
- `textSample` must not exceed 100 characters

**Relationships**:
- Used by TextClassificationService as return type
- Passed to ClassificationLogger for persistence
- Updates DocumentTypeContext state

**State Transitions**: N/A (immutable value type)

---

### 2. ClassificationLog (Database Model)

**Purpose**: Persisted record of classification history for future model retraining

**Fields**:
- `id: UUID` - Primary key, auto-generated
- `text: String` - Full original text that was classified
- `category: String` - Resulting category (stored as string for DB compatibility)
- `timestamp: Date` - When classification occurred
- `textLength: Int` - Character count of original text
- `extractedFeatures: String?` - Optional JSON blob of extracted features

**Validation Rules**:
- `id` must be unique (database constraint)
- `text` must not be empty
- `category` must be one of: "email", "message", "document", "social", "code", "search"
- `timestamp` must be valid date
- `textLength` must be > 0
- `extractedFeatures` must be valid JSON if present

**Relationships**:
- Managed by ClassificationLogger
- Queried for future model retraining analysis (out of scope for MVP)
- No foreign key relationships

**Indexes**:
- Primary index on `id`
- Index on `timestamp` (for chronological queries)
- Index on `category` (for category-based analysis)

**State Transitions**: Append-only (no updates or deletes in MVP)

---

### 3. TextFeatures (Value Type)

**Purpose**: Extracted linguistic and structural features from input text

**Fields**:
- `sentenceCount: Int` - Number of sentences detected
- `wordCount: Int` - Number of words
- `averageSentenceLength: Double` - Words per sentence
- `hasCompleteS entences: Bool` - Whether all sentences end with proper punctuation
- `formalityScore: Double` - 0.0-1.0, based on formal vocabulary presence
- `technicalTermCount: Int` - Count of code-related keywords detected
- `punctuationDensity: Double` - Ratio of punctuation chars to total chars
- `hasGreeting: Bool` - Presence of greeting words (Hey, Dear, etc.)
- `hasSignature: Bool` - Presence of signature words (Regards, Thanks, etc.)

**Validation Rules**:
- All counts must be >= 0
- `formalityScore` must be in range [0.0, 1.0]
- `punctuationDensity` must be in range [0.0, 1.0]
- `averageSentenceLength` must be >= 0

**Relationships**:
- Extracted by FeatureExtractor
- Used by DominantCharacteristicAnalyzer
- Optionally serialized to JSON and stored in ClassificationLog

**State Transitions**: N/A (immutable value type)

---

### 4. DocumentType (Existing Enum - Extended)

**Purpose**: Enumeration of supported text categories

**Cases**:
- `email` - Formal email communication
- `message` - Casual messaging (iMessage, Slack, etc.)
- `document` - Formal documents (reports, essays, etc.)
- `social` - Social media posts and updates
- `code` - Programming code snippets
- `search` - Search queries or commands

**Validation Rules**:
- Must be one of the 6 defined cases (enforced by Swift type system)

**Relationships**:
- Used by TextClassification, DocumentTypeContext
- Maps to string for database storage in ClassificationLog
- Consumed by TextEnhancementService for formatting decisions

**Extensions Needed**:
- Add `rawValue: String` for database serialization
- Add `displayName: String` for UI presentation (if needed)

---

### 5. ClassificationModelManager (Service State)

**Purpose**: Manages lifecycle of CoreML classification model

**State**:
- `model: NLModel?` - Lazily loaded CoreML model instance
- `isLoaded: Bool` - Whether model is currently loaded in memory
- `modelURL: URL` - Path to .mlmodel bundle in app resources

**Validation Rules**:
- `modelURL` must point to valid .mlmodel file
- `model` must be successfully compiled CoreML model when loaded

**Relationships**:
- Singleton instance owned by TextClassificationService
- Provides prediction interface to classification logic

**State Transitions**:
- Unloaded → Loading → Loaded
- Loading can fail → Error state (throws)

---

## Database Schema (GRDB)

### ClassificationLog Table

```sql
CREATE TABLE classificationLog (
    id TEXT PRIMARY KEY NOT NULL,
    text TEXT NOT NULL,
    category TEXT NOT NULL CHECK(category IN ('email', 'message', 'document', 'social', 'code', 'search')),
    timestamp REAL NOT NULL,
    textLength INTEGER NOT NULL CHECK(textLength > 0),
    extractedFeatures TEXT
);

CREATE INDEX idx_classificationLog_timestamp ON classificationLog(timestamp);
CREATE INDEX idx_classificationLog_category ON classificationLog(category);
```

### GRDB Record Conformance

```swift
struct ClassificationLog: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "classificationLog"

    var id: UUID
    var text: String
    var category: String
    var timestamp: Date
    var textLength: Int
    var extractedFeatures: String?
}
```

---

## Entity Lifecycle

### Classification Flow
1. User completes transcription → text available
2. TextClassificationService.classify(text) called
3. FeatureExtractor.extract(text) → TextFeatures
4. Load/reuse ClassificationModelManager.model
5. NLModel.predict(text) → raw prediction
6. DominantCharacteristicAnalyzer.analyze(features) → category override if needed
7. Create TextClassification(category, timestamp, textSample)
8. Async: ClassificationLogger.log(TextClassification, fullText, features)
9. ClassificationLog persisted to database

### Model Loading Flow
1. First classification request
2. ClassificationModelManager.loadModel()
3. Read modelURL from app bundle
4. Compile NLModel(contentsOf: modelURL)
5. Cache in memory for subsequent requests
6. Singleton lifetime (app session)

---

## Data Retention

### Classification Logs
- **Retention**: Indefinite (per FR-012: enable future model retraining)
- **Cleanup**: Not implemented in MVP (future: user-configurable retention period)
- **Privacy**: Stored locally only, never transmitted

### In-Memory Models
- **Retention**: App session lifetime (singleton)
- **Cleanup**: Released on app termination (automatic)

---

## Performance Considerations

### Database Operations
- **Insert latency**: <1ms per ClassificationLog entry (background queue)
- **Query optimization**: Indexes on timestamp and category for future analytics
- **Disk usage**: ~1KB per log entry, grows linearly with usage

### Memory Usage
- **CoreML model**: 2-5MB (loaded once, cached)
- **TextFeatures**: ~200 bytes per classification (transient)
- **TextClassification**: ~150 bytes per classification (transient)
- **Total runtime**: <10MB for classification subsystem

---

## Testing Strategy

### Unit Tests
- Validate field constraints (ranges, non-empty strings, valid enums)
- Test TextFeatures extraction correctness
- Verify ClassificationLog database CRUD operations
- Test DocumentType enum serialization

### Integration Tests
- End-to-end classification flow with database persistence
- Model loading and prediction accuracy
- Concurrent classification requests (thread safety)

### Contract Tests
- Verify TextClassification API stability
- Ensure ClassificationLogger interface consistency
- Validate database schema matches GRDB models
