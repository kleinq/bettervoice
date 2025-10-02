# Service Contract: TextEnhancementService

**Purpose**: Applies document-type-specific formatting and learned patterns to transcribed text

**Compliance**: FR-007 (document-type enhancement), FR-008 (filler removal), FR-019 (apply learning), FR-020 (optional cloud), QR-004 (learning improvement)

## Interface

```swift
protocol TextEnhancementServiceProtocol {
    /// Enhance transcribed text based on document type context
    /// - Parameters:
    ///   - text: Raw transcription from Whisper
    ///   - documentType: Detected document type
    ///   - applyLearning: Whether to apply learned user patterns
    ///   - useCloud: Whether to use external LLM if enabled
    /// - Returns: Enhanced text with metadata
    /// - Throws: EnhancementError if processing fails
    func enhance(
        text: String,
        documentType: DocumentType,
        applyLearning: Bool,
        useCloud: Bool
    ) async throws -> EnhancedText
}
```

## Error Types

```swift
enum EnhancementError: LocalizedError {
    case emptyInput
    case cloudAPIFailed(Error)
    case learningDatabaseUnavailable
    case processingTimeout

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "No text to enhance."
        case .cloudAPIFailed(let error):
            return "Cloud enhancement failed: \(error.localizedDescription). Using local-only enhancement."
        case .learningDatabaseUnavailable:
            return "Learning database unavailable. Proceeding without learned patterns."
        case .processingTimeout:
            return "Enhancement took too long and was cancelled."
        }
    }
}
```

## Input Constraints

**enhance**:
- `text` must not be empty
- `documentType` must be valid enum case
- If `applyLearning == true`, learning database must be accessible
- If `useCloud == true`, user preferences must have cloud enabled and API key configured
- Total processing time must be <2 seconds for local-only, <5 seconds with cloud

## Output Guarantees

**Returns EnhancedText** with:
- `enhancedText`: Non-empty formatted string
- `appliedRules`: List of enhancement rule names applied (e.g., ["RemoveFillers", "AddPunctuation", "FormatEmail"])
- `removedFillers`: List of specific filler words removed (e.g., ["um", "uh", "like"])
- `addedPunctuation`: Count of punctuation marks added
- `formattingChanges`: Descriptions of structural changes (e.g., ["Added 2 paragraphs", "Formatted as list"])
- `usedCloudAPI`: true if cloud enhancement succeeded
- `cloudProvider`: Provider name if cloud used
- `learningPatternsApplied`: Count of learned patterns applied
- `confidence`: 0.7-1.0 for good enhancement, 0.3-0.7 for uncertain

## Enhancement Pipeline Stages

### Stage 1: Normalize (always)
- Trim leading/trailing whitespace
- Normalize Unicode (NFC)
- Remove excessive spaces (>2 consecutive → 1)
- Fix common ASR artifacts (double words, broken contractions)

### Stage 2: Remove Fillers (always, per FR-008)
Patterns to remove:
- "um", "uh", "uhm", "erm"
- "like" (when not comparative)
- "you know"
- "kind of", "sort of" (in non-essential usage)
- "I mean"
- "basically", "actually" (when redundant)

### Stage 3: Punctuate (always)
- Detect sentence boundaries (pauses, intonation cues)
- Capitalize first word of sentences
- Add periods at sentence ends
- Add commas for natural pauses
- Add question marks for interrogative sentences

### Stage 4: Format by Document Type

**Email (.email)**:
- Detect and format greeting ("hi john" → "Hi John,")
- Detect name mentions and capitalize
- Format email addresses
- Format phone numbers (US/international)
- Format URLs
- Create paragraph breaks (double newline between topics)
- Detect closing ("thanks" → "Thanks,")
- Professional tone (avoid slang)

**Message (.message)**:
- Casual tone preservation
- Minimal punctuation (conversational)
- Emoji detection and placement (if user patterns show emoji usage)
- Short paragraphs or single block
- Quick response optimizations ("yes" → "Yes!", "ok" → "OK")

**Document (.document)**:
- Detect and format numbered lists ("first... second... third..." → "1. ... 2. ... 3. ...")
- Detect and format bullet lists ("item one, item two" → "• item one\n• item two")
- Paragraph organization (topic detection)
- Heading detection ("section one" → "## Section One")
- Professional academic tone
- Format quotations

**Search Query (.searchQuery)**:
- Extract key terms only
- Remove all filler words aggressively
- Remove articles (a, an, the) unless critical
- Lowercase (except proper nouns)
- Concise output (<10 words typically)
- Example: "um I want to find information about climate change effects" → "climate change effects"

### Stage 5: Apply Learning (if enabled)
- Query `LearningPattern` table for document type
- Find similar patterns using edit distance (threshold 0.8)
- Apply highest-confidence learned patterns
- Track which patterns were applied

### Stage 6: Cloud Enhancement (if enabled and API configured)
- Send locally-enhanced text to configured LLM
- Use document-type-specific system prompt
- Timeout after 30 seconds (configurable)
- Fallback to local-only on failure
- Compare local vs cloud output, log improvements

## Performance Requirements

- **Local-only**: < 2 seconds total (all stages 1-5)
- **With cloud**: < 5 seconds total (includes API call)
- **Memory**: < 50MB for processing (text manipulation only)
- **CPU**: < 10% average (mostly string operations)

## Testing Strategy

```swift
class TextEnhancementServiceContractTests: XCTestCase {
    func testEnhanceRemovesFillerWords() async throws {
        // Given
        let service = TextEnhancementService()
        let text = "um so I was thinking uh we should like meet tomorrow you know"

        // When
        let result = try await service.enhance(
            text: text,
            documentType: .message,
            applyLearning: false,
            useCloud: false
        )

        // Then
        XCTAssertFalse(result.enhancedText.contains("um"))
        XCTAssertFalse(result.enhancedText.contains("uh"))
        XCTAssertTrue(result.removedFillers.contains("um"))
        XCTAssertGreaterThan(result.removedFillers.count, 0)
    }

    func testEnhanceFormatsEmailProperly() async throws {
        // Given
        let service = TextEnhancementService()
        let text = "hi sarah I wanted to follow up on our meeting thanks"

        // When
        let result = try await service.enhance(
            text: text,
            documentType: .email,
            applyLearning: false,
            useCloud: false
        )

        // Then
        XCTAssertTrue(result.enhancedText.hasPrefix("Hi Sarah"))
        XCTAssertTrue(result.enhancedText.contains("Thanks,"))
        XCTAssertTrue(result.appliedRules.contains("FormatEmail"))
    }

    func testEnhanceCreatesSearchQuery() async throws {
        // Given
        let service = TextEnhancementService()
        let text = "um I want to find like information about the best restaurants in San Francisco"

        // When
        let result = try await service.enhance(
            text: text,
            documentType: .searchQuery,
            applyLearning: false,
            useCloud: false
        )

        // Then
        XCTAssertFalse(result.enhancedText.contains("um"))
        XCTAssertFalse(result.enhancedText.contains("I want to find"))
        XCTAssertTrue(result.enhancedText.contains("restaurants San Francisco"))
        XCTAssertLessThan(result.enhancedText.split(separator: " ").count, 10)
    }

    func testEnhanceAppliesLearningPatterns() async throws {
        // Given
        let service = TextEnhancementService()
        let learningService = MockLearningService()
        learningService.mockPatterns = [
            LearningPattern(
                documentType: .email,
                originalText: "thanks",
                editedText: "Thank you so much,",
                frequency: 5
            )
        ]
        let text = "meeting was great thanks"

        // When
        let result = try await service.enhance(
            text: text,
            documentType: .email,
            applyLearning: true,
            useCloud: false
        )

        // Then
        XCTAssertTrue(result.enhancedText.contains("Thank you so much"))
        XCTAssertGreaterThan(result.learningPatternsApplied, 0)
    }

    func testEnhanceUsesCloudWhenEnabled() async throws {
        // Given
        let service = TextEnhancementService()
        let mockCloudClient = MockLLMClient()
        mockCloudClient.mockResponse = "Meeting was great. Thank you very much!"
        let text = "meeting was great thanks"

        // When
        let result = try await service.enhance(
            text: text,
            documentType: .email,
            applyLearning: false,
            useCloud: true
        )

        // Then
        XCTAssertTrue(result.usedCloudAPI)
        XCTAssertNotNil(result.cloudProvider)
        XCTAssertTrue(result.confidence > 0.8)
    }

    func testEnhanceFallsBackOnCloudFailure() async throws {
        // Given
        let service = TextEnhancementService()
        let mockCloudClient = MockLLMClient()
        mockCloudClient.simulateError = true
        let text = "hello world"

        // When
        let result = try await service.enhance(
            text: text,
            documentType: .message,
            applyLearning: false,
            useCloud: true
        )

        // Then
        XCTAssertFalse(result.usedCloudAPI)  // Fell back to local
        XCTAssertFalse(result.enhancedText.isEmpty)  // Still got result
    }

    func testEnhanceMeetsPerformanceRequirement() async throws {
        // Given
        let service = TextEnhancementService()
        let text = String(repeating: "This is a test sentence. ", count: 50)

        // When
        let start = Date()
        let result = try await service.enhance(
            text: text,
            documentType: .document,
            applyLearning: true,
            useCloud: false
        )
        let elapsed = Date().timeIntervalSince(start)

        // Then
        XCTAssertLessThan(elapsed, 2.0, "Local-only must complete in <2s")
    }
}
```

## Integration Points

**Upstream**:
- `TranscriptionQueue` - orchestrates transcription → enhancement pipeline

**Downstream**:
- `FillerWordRemover` - Stage 2 implementation
- `DocumentTypeDetector` - provides document type
- `LearningService` - Stage 5, pattern retrieval
- `LLMEnhancementService` - Stage 6, cloud API calls
- `FormatApplier` - Stage 4, document-specific formatting

**Data Flow**:
```
WhisperService → raw String
                     ↓
TextEnhancementService.enhance()
                     ↓
             EnhancedText model
                     ↓
                PasteService
```

## Notes

- Enhancement is deterministic for local-only (same input → same output)
- Cloud enhancement adds non-determinism but higher quality
- Learning patterns improve over time as user corrections accumulate
- Filler word removal is aggressive but configurable per user feedback
- Each stage is independently testable via internal protocols
