# Service Contract: ClassificationLogger

**Feature**: 003-apple-s-naturallanguage
**Date**: 2025-10-05
**Type**: Swift Service API

## Overview
ClassificationLogger provides async persistence of classification results to SQLite database for future model retraining.

## Interface

### Primary Method

```swift
func log(
    classification: TextClassification,
    fullText: String,
    features: TextFeatures?
) async
```

**Purpose**: Persist classification result to database for future analysis

**Parameters**:
- `classification: TextClassification` - The classification result to log
- `fullText: String` - Complete original text that was classified
- `features: TextFeatures?` - Optional extracted features (for advanced analysis)

**Returns**: Void (fire-and-forget async operation)

**Throws**: Does NOT throw - errors are logged internally but don't propagate

**Performance**:
- Latency: <1ms database insert (on background queue)
- Non-blocking: Caller not blocked by database I/O
- Batching: Not implemented in MVP (future optimization)

**Examples**:

```swift
// Basic logging
let classification = TextClassification(
    category: .message,
    timestamp: Date(),
    textSample: "Hey Sarah, are we..."
)
await logger.log(
    classification: classification,
    fullText: "Hey Sarah, are we still on for lunch today?",
    features: nil
)

// Logging with features (for analysis)
let features = TextFeatures(
    sentenceCount: 1,
    wordCount: 8,
    formalityScore: 0.2,
    // ...
)
await logger.log(
    classification: classification,
    fullText: fullText,
    features: features
)
```

**Contract Constraints**:
1. MUST persist to database within 100ms of call
2. MUST NOT block caller's thread (async implementation)
3. MUST handle database errors gracefully (log but don't crash)
4. MUST serialize TextFeatures to JSON if provided
5. MUST generate unique UUID for each log entry

---

## Supporting Types

### ClassificationLog (Database Model)

```swift
struct ClassificationLog: Codable, FetchableRecord, PersistableRecord {
    var id: UUID
    var text: String
    var category: String // DocumentType.rawValue
    var timestamp: Date
    var textLength: Int
    var extractedFeatures: String? // JSON
}
```

---

## Behavioral Contracts

### BC-1: Successful Logging
**Given**: Valid classification, fullText, and features
**When**: `log()` is called
**Then**: Entry appears in classificationLog table within 100ms

### BC-2: Empty Text Handling
**Given**: fullText is empty string
**When**: `log()` is called
**Then**: Log entry NOT created (silently skipped)

### BC-3: Database Error Handling
**Given**: Database is locked or disk full
**When**: `log()` is called
**Then**: Error logged to console, no exception thrown to caller

### BC-4: Features Serialization
**Given**: features parameter is non-nil
**When**: `log()` is called
**Then**: extractedFeatures column contains valid JSON representation

### BC-5: Features Omission
**Given**: features parameter is nil
**When**: `log()` is called
**Then**: extractedFeatures column is NULL in database

### BC-6: Concurrent Logging
**Given**: Multiple concurrent log() calls
**When**: All executing simultaneously
**Then**: All entries persisted correctly without corruption

---

## Integration Points

### Callers
- **TextClassificationService**: Calls log() after every successful classification
- **Test Infrastructure**: Calls log() in integration tests

### Dependencies
- **GRDB.swift**: Database access layer
- **DatabaseQueue**: GRDB queue for thread-safe writes
- **JSONEncoder**: For serializing TextFeatures to JSON

### Side Effects
- Appends row to classificationLog table
- Disk usage increases linearly with usage (~1KB per entry)
- No cleanup or deletion in MVP

---

## Database Schema

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

---

## Test Requirements

### Contract Tests (Must Pass Before Implementation)

```swift
// Test file: ClassificationLoggerContractTests.swift

func testLog_validClassification_persistsToDatabase() async throws
func testLog_withFeatures_serializesFeaturesToJSON() async throws
func testLog_withoutFeatures_leavesExtractedFeaturesNull() async throws
func testLog_emptyText_skipsLogging() async throws
func testLog_concurrent_handlesMultipleWrites() async throws
func testLog_databaseError_doesNotThrow() async throws
func testLog_performance_completesUnder1ms() async throws
```

### Integration Tests

```swift
func testLog_roundTrip_retrievesCorrectData() async throws {
    // Log an entry
    await logger.log(classification: testClassification, fullText: testText, features: nil)

    // Query database
    let logs = try await fetchRecentLogs(limit: 1)

    // Verify
    XCTAssertEqual(logs.first?.category, "message")
    XCTAssertEqual(logs.first?.text, testText)
}
```

---

## Non-Functional Requirements

### Performance
- **Insert latency**: <1ms per log entry
- **Memory**: <100KB overhead for logger service
- **Disk I/O**: Async, non-blocking to caller

### Reliability
- **Error isolation**: Database failures don't crash app
- **Data integrity**: ACID guarantees via SQLite/GRDB
- **Thread safety**: Fully concurrent-safe via GRDB queue

### Scalability
- **Capacity**: Handles 10,000+ log entries without degradation
- **Query performance**: Indexes support efficient timestamp/category queries
- **Cleanup**: Future feature - not implemented in MVP

---

## Privacy & Security

- **Local only**: Data never leaves device
- **Encryption**: Not implemented in MVP (SQLite plaintext)
- **User control**: Future: allow user to clear logs
- **Retention**: Indefinite (per FR-012)

---

## Change Log

**v1.0.0 (2025-10-05)**: Initial contract definition for MVP
