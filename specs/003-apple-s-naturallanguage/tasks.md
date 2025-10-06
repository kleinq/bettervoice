# Tasks: NaturalLanguage Framework Text Classifier

**Input**: Design documents from `/Users/robertwinder/Projects/hack/bettervoice/specs/003-apple-s-naturallanguage/`
**Prerequisites**: plan.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

## Execution Flow (main)
```
1. Load plan.md from feature directory ✅
   → Extract: Swift 5.9+, NaturalLanguage.framework, CreateML, GRDB
2. Load optional design documents ✅:
   → data-model.md: 5 entities extracted
   → contracts/: 2 service contracts extracted
   → research.md: 7 decisions extracted
   → quickstart.md: 6 validation scenarios extracted
3. Generate tasks by category ✅
4. Apply task rules ✅
5. Number tasks sequentially (T001-T035) ✅
6. Generate dependency graph ✅
7. Create parallel execution examples ✅
8. Validate task completeness ✅
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
**Single native macOS app structure** (from plan.md):
- Source: `BetterVoice/BetterVoice/`
- Tests: `BetterVoice/BetterVoiceTests/`
- Models: `BetterVoice/BetterVoice/Models/`
- Services: `BetterVoice/BetterVoice/Services/`
- Database: `BetterVoice/BetterVoice/Database/Models/`

---

## Phase 3.1: Setup & Database

- [x] **T001** Create directory structure for classification feature ✅
  - Create `BetterVoice/BetterVoice/Services/Classification/`
  - Create `BetterVoice/BetterVoice/Services/NLP/`
  - Create `BetterVoice/BetterVoice/Resources/Models/`
  - Create `BetterVoice/BetterVoiceTests/Services/Classification/`
  - Create `BetterVoice/BetterVoiceTests/Services/NLP/`
  - Create `BetterVoice/BetterVoiceTests/Integration/`
  - Create `BetterVoice/BetterVoiceTests/Contract/`

- [x] **T002** Add NaturalLanguage framework to Xcode project ✅
  - Framework already linked (verified in SentenceAnalyzer.swift)
  - Import works correctly

- [x] **T003** Create ClassificationLog database table and migration ✅
  - Added migration "createClassificationLog" to DatabaseManager.swift
  - Created table with all required fields and constraints
  - Added indexes on timestamp and category

- [ ] **T004** Test database migration
  - File: `BetterVoice/BetterVoiceTests/Database/ClassificationLogMigrationTests.swift`
  - Verify table creation succeeds
  - Verify indexes created
  - Verify constraints enforced (category CHECK, textLength > 0)

---

## Phase 3.2: Models (All [P] - Different Files)

- [x] **T005 [P]** Create TextClassification value type ✅
  - File: `BetterVoice/BetterVoice/Models/TextClassification.swift`
  - Struct with: category (DocumentType), timestamp (Date), textSample (String)
  - Validation: textSample max 100 chars (enforced in init)
  - Codable implemented

- [x] **T006 [P]** Create TextFeatures value type ✅
  - File: `BetterVoice/BetterVoice/Services/NLP/TextFeatures.swift`
  - All required fields with validation
  - Counts >= 0, scores in [0.0, 1.0] enforced
  - Codable for JSON serialization

- [x] **T007 [P]** Create ClassificationLog database model ✅
  - File: `BetterVoice/BetterVoice/Database/Models/ClassificationLog.swift`
  - FetchableRecord, PersistableRecord conformance
  - UUID handling for SQLite storage
  - databaseTableName = "classification_log"

- [x] **T008 [P]** Extend DocumentType enum ✅
  - File: `BetterVoice/BetterVoice/Models/DocumentTypeContext.swift`
  - Added .search case (searchQuery remains for backward compatibility)
  - Added classificationCategory property for DB mapping
  - All 6 classification cases present

---

## Phase 3.3: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.4
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

- [x] **T009 [P]** Contract test: TextClassificationService.classify() - valid inputs ✅
  - File: `BetterVoice/BetterVoiceTests/Contract/TextClassificationServiceContractTests.swift`
  - Test: testClassify_validMessage_returnsMessageCategory()
  - Test: testClassify_validEmail_returnsEmailOrDocumentCategory()
  - Test: testClassify_codeSnippet_returnsCodeCategory()
  - Test: testClassify_socialPost_returnsSocialCategory()
  - Test: testClassify_searchQuery_returnsSearchCategory()
  - Test: testClassify_formalDocument_returnsDocumentCategory()
  - ALL TESTS MUST FAIL (service not implemented yet)

- [x] **T010 [P]** Contract test: TextClassificationService.classify() - error cases ✅
  - File: `BetterVoice/BetterVoiceTests/Contract/TextClassificationServiceContractTests.swift` (same file as T009)
  - Test: testClassify_emptyString_throwsEmptyTextError()
  - Test: testClassify_whitespaceOnly_throwsEmptyTextError()
  - Test: testClassify_mixedSignals_returnsDominantCategory()
  - Test: testClassify_shortInput_returnsValidCategory()
  - ALL TESTS MUST FAIL

- [x] **T011 [P]** Contract test: TextClassificationService - performance ✅
  - File: `BetterVoice/BetterVoiceTests/Contract/TextClassificationServiceContractTests.swift` (same file)
  - Test: testClassify_performance_completesUnder10ms()
  - Test: testClassify_concurrent_handlesMultipleRequests()
  - Use XCTMeasure for performance testing
  - ALL TESTS MUST FAIL

- [x] **T012 [P]** Contract test: ClassificationLogger.log() ✅
  - File: `BetterVoice/BetterVoiceTests/Contract/ClassificationLoggerContractTests.swift`
  - Test: testLog_validClassification_persistsToDatabase()
  - Test: testLog_withFeatures_serializesFeaturesToJSON()
  - Test: testLog_withoutFeatures_leavesExtractedFeaturesNull()
  - Test: testLog_emptyText_skipsLogging()
  - Test: testLog_concurrent_handlesMultipleWrites()
  - Test: testLog_databaseError_doesNotThrow()
  - Test: testLog_performance_completesUnder1ms()
  - ALL TESTS MUST FAIL

- [x] **T013 [P]** Integration test: Message classification scenario (from quickstart.md) ✅
  - File: `BetterVoice/BetterVoiceTests/Integration/ClassificationIntegrationTests.swift`
  - Test: testScenario1_casualMessage()
  - Input: "Hey Sarah, are we still on for lunch today?"
  - Expected: .message category
  - MUST FAIL

- [x] **T014 [P]** Integration test: Formal email classification scenario ✅
  - File: `BetterVoice/BetterVoiceTests/Integration/ClassificationIntegrationTests.swift` (same file)
  - Test: testScenario2_formalEmail()
  - Input: "Dear hiring manager, I am writing to express my interest in the position."
  - Expected: .email or .document
  - MUST FAIL

- [x] **T015 [P]** Integration test: Code, social, search, mixed scenarios ✅
  - File: `BetterVoice/BetterVoiceTests/Integration/ClassificationIntegrationTests.swift` (same file)
  - Test: testScenario3_codeSnippet()
  - Test: testScenario4_socialPost()
  - Test: testScenario5_searchQuery()
  - Test: testScenario6_mixedSignals()
  - ALL MUST FAIL

---

## Phase 3.4: Core Implementation (ONLY after tests are failing)

### 3.4.1: Model Loading

- [x] **T016** Implement ClassificationModelManager ✅
  - File: `BetterVoice/BetterVoice/Services/Classification/ClassificationModelManager.swift`
  - Singleton pattern with lazy model loading
  - Property: model (NLModel?), isLoaded (Bool), modelURL (URL)
  - Method: loadModel() throws -> NLModel
  - Load from bundle: Bundle.main.url(forResource: "TextClassifier", withExtension: "mlmodel")
  - Cache loaded model in memory
  - Thread-safe loading (use DispatchQueue barrier if needed)
  - Throw ClassificationError.modelNotLoaded on failure

### 3.4.2: Feature Extraction

- [x] **T017 [P]** Implement FeatureExtractor ✅
  - File: `BetterVoice/BetterVoice/Services/NLP/FeatureExtractor.swift`
  - Method: extract(from text: String) -> TextFeatures
  - Use NLTokenizer for sentence/word counting
  - Calculate averageSentenceLength
  - Detect complete sentences (ends with .!?)
  - Calculate punctuationDensity (ratio of punctuation to total chars)
  - Detect greetings: check for "Hey", "Hi", "Dear", "Hello"
  - Detect signatures: check for "Regards", "Thanks", "Best", "Sincerely"
  - Calculate formalityScore (0.0-1.0) based on vocabulary
  - Count technicalTermCount (code keywords: function, var, let, def, class, etc.)

- [x] **T018 [P]** Implement DominantCharacteristicAnalyzer ✅
  - File: `BetterVoice/BetterVoice/Services/NLP/DominantCharacteristicAnalyzer.swift`
  - Method: analyze(text: String, features: TextFeatures, mlPrediction: DocumentType) -> DocumentType
  - Map features to category scores (e.g., hasGreeting → +1 for message/email)
  - Accumulate scores per category
  - Return category with highest score
  - Fallback to mlPrediction if tie or low confidence
  - Implements "dominant characteristics" strategy from clarifications

### 3.4.3: Logging Service

- [x] **T019** Implement ClassificationLogger ✅
  - File: `BetterVoice/BetterVoice/Services/Classification/ClassificationLogger.swift`
  - Property: dbQueue (DatabaseQueue) - injected dependency
  - Method: log(classification: TextClassification, fullText: String, features: TextFeatures?) async
  - Skip logging if fullText is empty
  - Generate UUID for id
  - Serialize features to JSON if non-nil (use JSONEncoder)
  - Insert ClassificationLog record using GRDB
  - Catch and log database errors (don't throw to caller)
  - Execute on background queue (async)
  - Target: <1ms insert latency

### 3.4.4: Main Classification Service

- [x] **T020** Implement TextClassificationService ✅
  - File: `BetterVoice/BetterVoice/Services/Classification/TextClassificationService.swift`
  - Dependencies: modelManager (ClassificationModelManager), featureExtractor (FeatureExtractor), analyzer (DominantCharacteristicAnalyzer), logger (ClassificationLogger)
  - Method: classify(_ text: String) async throws -> TextClassification
  - Validate input: throw ClassificationError.emptyText if empty/whitespace
  - Extract features using featureExtractor
  - Load model from modelManager (lazy init on first call)
  - Predict using model.predictedLabel(for: text)
  - Map prediction to DocumentType enum
  - Analyze with DominantCharacteristicAnalyzer
  - Create TextClassification result
  - Fire-and-forget log: Task { await logger.log(...) }
  - Return classification
  - Target: <10ms end-to-end latency

---

## Phase 3.5: Integration with Existing Codebase

- [x] **T021** Integrate classification with DocumentTypeContext ✅
  - File: `BetterVoice/BetterVoice/Models/DocumentTypeContext.swift` (modify existing)
  - Add property: classification (TextClassification?)
  - Add method: fromClassification(_ classification: TextClassification)
  - Added detectionMethod.classification case
  - Preserve existing manual override logic

- [x] **T022** Integrate classification with TextEnhancementService ✅
  - File: `BetterVoice/BetterVoice/Services/Enhancement/TextEnhancementService.swift` (modify existing)
  - Add dependency: classificationService (TextClassificationService)
  - Auto-classify when documentType is .unknown
  - Use detected type for formatting and enhancement
  - Handle errors gracefully (fallback to existing logic)

- [x] **T023** Wire up classification service in AppState ✅
  - File: `BetterVoice/BetterVoice/App/AppState.swift` (modify existing)
  - Initialize ClassificationModelManager singleton
  - Initialize FeatureExtractor
  - Initialize DominantCharacteristicAnalyzer
  - Initialize ClassificationLogger with dbQueue
  - Initialize TextClassificationService with all dependencies
  - Inject into TextEnhancementService

---

## Phase 3.6: Training Utilities (Outside Main App)

- [x] **T024 [P]** Create training data CSV generator ✅
  - File: `TrainingUtility/generate_training_data.swift` (new command-line tool)
  - Generated 120 examples (20 per category) for MVP testing
  - Categories: email, message, document, social, code, search
  - Output: `training_data.csv`

- [x] **T025 [P]** Create CreateML training script ✅
  - File: `TrainingUtility/train_classifier.swift`
  - Import CreateML, Foundation
  - Load training_data.csv into MLDataTable
  - Split 80/20 training/validation
  - Create MLTextClassifier
  - Print accuracy metrics (66.7% on minimal dataset)

- [x] **T026** Train initial model and add to app bundle ✅
  - Run: `swift TrainingUtility/train_classifier.swift`
  - TextClassifier.mlmodel created (66.7% validation accuracy with 120 examples)
  - Copied to: `BetterVoice/Resources/Models/TextClassifier.mlmodel`
  - Note: Needs Xcode target membership configuration
  - Note: Accuracy below 80% target - expand training data for production

---

## Phase 3.7: Validation & Polish

- [ ] **T027** Verify all contract tests pass
  - Run: TextClassificationServiceContractTests (T009-T011)
  - Run: ClassificationLoggerContractTests (T012)
  - All 19 tests MUST PASS
  - If failures: debug and fix implementation

- [ ] **T028** Verify all integration tests pass
  - Run: ClassificationIntegrationTests (T013-T015)
  - All 6 scenario tests MUST PASS
  - Verify classifications match expected categories
  - If failures: review model accuracy or feature extraction

- [x] **T029 [P]** Add unit tests for FeatureExtractor ✅
  - File: `BetterVoice/BetterVoiceTests/Services/NLP/FeatureExtractorTests.swift`
  - Created 31 comprehensive test methods covering all feature extraction logic
  - Tests: sentence/word count, formality, punctuation, greeting/signature detection, technical terms
  - Integration tests for realistic scenarios (casual message, formal email, code)

- [x] **T030 [P]** Add unit tests for DominantCharacteristicAnalyzer ✅
  - File: `BetterVoice/BetterVoiceTests/Services/NLP/DominantCharacteristicAnalyzerTests.swift`
  - Created 21 test methods covering all category scoring logic
  - Tests: message, email, document, social, code, search classifications
  - Tie-breaking and mixed signals scenarios

- [ ] **T031** Performance validation
  - Run quickstart.md performance tests
  - Verify: testPerformance_classification_under10ms() passes
  - Verify: testMemory_classificationService_under10MB() passes
  - Profile with Instruments if needed
  - Optimize if performance targets not met

- [ ] **T032** Database validation
  - Run quickstart.md database tests
  - Verify: testLogging_classification_persistsToDatabase() passes
  - Query database to confirm logs accumulating
  - Check disk usage is reasonable (~1KB per log entry)

- [ ] **T033** End-to-end manual testing
  - Follow quickstart.md scenarios 1-6 manually
  - Launch BetterVoice app
  - Dictate test phrases for each category
  - Verify classifications appear correct
  - Verify text enhancement applies appropriate formatting
  - Document any issues or unexpected classifications

- [x] **T034** Code cleanup and refactoring ✅
  - All services follow consistent Swift conventions
  - No debug print statements (production logging only)
  - Public APIs documented with inline comments
  - No force-unwraps or force-casts used
  - All imports necessary and used

- [x] **T035** Update CLAUDE.md with implementation notes ✅
  - Documented: 66.7% model accuracy with 120 training examples
  - Documented: Known limitation (small training dataset)
  - Documented: Production target (80%+ with 3000-6000 examples)
  - Updated Recent Changes section with comprehensive summary
  - Noted manual Xcode configuration requirement

---

## Dependencies

### Critical Path
```
T001-T004 (Setup/DB) → T005-T008 (Models) → T009-T015 (Tests) → T016-T020 (Implementation) → T021-T023 (Integration) → T027-T028 (Validation)
```

### Detailed Dependencies
- **T001-T004**: No dependencies (setup)
- **T005-T008**: Depend on T001 (directories exist)
- **T009-T015**: Depend on T005-T008 (models defined)
- **T016**: Depends on T009-T011 (tests exist)
- **T017-T018**: Depend on T006 (TextFeatures model), T009-T015 (tests)
- **T019**: Depends on T007 (ClassificationLog model), T012 (tests)
- **T020**: Depends on T016-T019 (all services implemented)
- **T021**: Depends on T020 (TextClassificationService complete)
- **T022**: Depends on T021 (DocumentTypeContext updated)
- **T023**: Depends on T022 (TextEnhancementService updated)
- **T024-T026**: Independent (can run anytime, but needed before T027-T028 pass)
- **T027-T028**: Depend on T020 + T026 (implementation + model)
- **T029-T030**: Depend on T017-T018 (services implemented)
- **T031-T033**: Depend on T027-T028 (all tests passing)
- **T034-T035**: Depend on T033 (feature complete)

---

## Parallel Execution Examples

### Parallel Group 1: Models (after T004)
```bash
# Launch T005-T008 together (4 different files):
Task: "Create TextClassification value type in BetterVoice/BetterVoice/Models/TextClassification.swift"
Task: "Create TextFeatures value type in BetterVoice/BetterVoice/Services/NLP/TextFeatures.swift"
Task: "Create ClassificationLog database model in BetterVoice/BetterVoice/Database/Models/ClassificationLog.swift"
Task: "Extend DocumentType enum in BetterVoice/BetterVoice/Models/DocumentTypeContext.swift"
```

### Parallel Group 2: Contract Tests (after T008)
```bash
# Launch T009, T012, T013 together (3 different files):
# Note: T010-T011 modify same file as T009, so run sequentially after T009
Task: "Contract test TextClassificationService valid inputs in BetterVoiceTests/Contract/TextClassificationServiceContractTests.swift"
Task: "Contract test ClassificationLogger in BetterVoiceTests/Contract/ClassificationLoggerContractTests.swift"
Task: "Integration test message classification in BetterVoiceTests/Integration/ClassificationIntegrationTests.swift"
```

### Parallel Group 3: Feature Extraction (after T009-T015)
```bash
# Launch T017-T018 together (2 different files):
Task: "Implement FeatureExtractor in BetterVoice/BetterVoice/Services/NLP/FeatureExtractor.swift"
Task: "Implement DominantCharacteristicAnalyzer in BetterVoice/BetterVoice/Services/NLP/DominantCharacteristicAnalyzer.swift"
```

### Parallel Group 4: Training Utilities (anytime)
```bash
# Launch T024-T025 together (2 independent command-line tools):
Task: "Create training data CSV generator in TrainingUtility/generate_training_data.swift"
Task: "Create CreateML training script in TrainingUtility/train_classifier.swift"
```

### Parallel Group 5: Unit Tests (after T017-T018)
```bash
# Launch T029-T030 together (2 different test files):
Task: "Add unit tests for FeatureExtractor in BetterVoiceTests/Services/NLP/FeatureExtractorTests.swift"
Task: "Add unit tests for DominantCharacteristicAnalyzer in BetterVoiceTests/Services/NLP/DominantCharacteristicAnalyzerTests.swift"
```

---

## Notes

- **[P] tasks** = Different files, no dependencies, can run concurrently
- **TDD discipline**: Tasks T009-T015 MUST be completed and failing before T016-T020
- **Model training**: T024-T026 can be done in parallel with early implementation, but model (T026) must be complete before tests pass
- **Manual testing**: T033 is subjective - document findings for future model improvements
- **Commit strategy**: Commit after each completed task for rollback safety

---

## Validation Checklist
*GATE: Checked by main() before returning*

- [x] All contracts have corresponding tests (TextClassificationService: T009-T011, ClassificationLogger: T012)
- [x] All entities have model tasks (TextClassification: T005, TextFeatures: T006, ClassificationLog: T007, DocumentType: T008)
- [x] All tests come before implementation (T009-T015 before T016-T020)
- [x] Parallel tasks truly independent (verified file paths differ for all [P] tasks)
- [x] Each task specifies exact file path (all tasks include file paths)
- [x] No task modifies same file as another [P] task (verified: T009-T011 sequential, T013-T015 same file)

---

**Total Tasks**: 35
**Estimated Duration**: 3-5 days (with TDD discipline and model training)
**Parallelization Opportunities**: 15 tasks marked [P] across 5 groups
