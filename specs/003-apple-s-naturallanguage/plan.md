
# Implementation Plan: NaturalLanguage Framework Text Classifier

**Branch**: `003-apple-s-naturallanguage` | **Date**: 2025-10-05 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/Users/robertwinder/Projects/hack/bettervoice/specs/003-apple-s-naturallanguage/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Implement on-device text classification using Apple's NaturalLanguage framework with a custom-trained CreateML model to automatically categorize dictated text into six types (email, message, document, social, code, search) for context-aware text enhancement. The system will analyze text features (sentence structure, formality indicators, technical terms, length patterns, punctuation density) to achieve 80% accuracy with <10ms inference time, operating completely offline while logging classifications for future model improvement.

## Technical Context
**Language/Version**: Swift 5.9+ (targeting macOS 12.0+)
**Primary Dependencies**: NaturalLanguage.framework, CreateML.framework (Apple built-in), GRDB.swift (for classification logging)
**Storage**: SQLite via GRDB.swift for classification history/logs; CoreML model bundle for trained classifier
**Testing**: XCTest for unit and integration tests; CreateML for model validation
**Target Platform**: macOS 12.0+ (native SwiftUI application)
**Project Type**: Single native macOS app (existing BetterVoice codebase)
**Performance Goals**: <10ms classification inference, 80% minimum accuracy, <5MB model size
**Constraints**: Completely offline/on-device, no network required, <10MB memory footprint for classification service, no user override capability
**Scale/Scope**: 6 content categories, real-time classification per transcription event, indefinite classification log retention for retraining

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Privacy-First Architecture ✅ PASS
- All classification processing occurs on-device using NaturalLanguage framework
- No external data transmission (FR-004, FR-005)
- Classification logs stored locally only for model retraining

### II. Local-First Processing ✅ PASS
- Core classification functionality uses local CoreML model (FR-004)
- No network connectivity required (FR-004)
- Operates completely offline

### III. Native Platform Integration ✅ PASS
- Uses native Apple frameworks: NaturalLanguage, CreateML, CoreML
- SwiftUI integration for existing BetterVoice app
- Follows macOS platform standards

### IV. Test-Driven Development (NON-NEGOTIABLE) ✅ PASS
- TDD approach planned in Phase 1 with contract tests
- XCTest framework for unit/integration tests
- Red-Green-Refactor cycle enforced through task ordering

### V. Performance & Resource Efficiency ✅ PASS
- <10ms classification inference (FR-003) - well under UI responsiveness threshold
- <10MB memory footprint for classification service - within 200MB app limit
- Efficient CoreML inference, no continuous background processing

### VI. Optional Cloud Enhancement ✅ PASS
- Feature is entirely local, no cloud component
- Future cloud model training could be optional enhancement
- N/A for current implementation scope

### VII. User Control & Transparency ✅ PASS
- System provides deterministic classification (FR-011)
- No user override needed per clarified requirements (FR-013)
- Classification results visible through existing app UI integration

### Security Requirements ✅ PASS
- No API keys required (local-only)
- Classification logs in sandboxed app container (GRDB SQLite)
- No network requests

### Performance Standards ✅ PASS
- <10ms inference meets <100ms UI responsiveness requirement
- Resource usage within constitutional limits
- Quality: 80% accuracy baseline (FR-014)

**GATE STATUS**: ✅ ALL CHECKS PASSED - No violations or complexity deviations

## Project Structure

### Documentation (this feature)
```
specs/[###-feature]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
BetterVoice/BetterVoice/
├── Models/
│   └── DocumentTypeContext.swift (existing - will extend)
├── Services/
│   ├── Enhancement/
│   │   └── TextEnhancementService.swift (existing - will integrate)
│   ├── Classification/              (NEW)
│   │   ├── TextClassificationService.swift
│   │   ├── ClassificationModelManager.swift
│   │   └── ClassificationLogger.swift
│   └── NLP/                          (NEW)
│       ├── FeatureExtractor.swift
│       └── DominantCharacteristicAnalyzer.swift
├── Resources/
│   └── Models/                       (NEW)
│       └── TextClassifier.mlmodel
└── Database/
    └── Models/
        └── ClassificationLog.swift   (NEW)

BetterVoice/BetterVoiceTests/
├── Services/
│   ├── Classification/               (NEW)
│   │   ├── TextClassificationServiceTests.swift
│   │   ├── ClassificationModelManagerTests.swift
│   │   └── ClassificationLoggerTests.swift
│   └── NLP/                          (NEW)
│       ├── FeatureExtractorTests.swift
│       └── DominantCharacteristicAnalyzerTests.swift
├── Integration/                      (NEW)
│   └── ClassificationIntegrationTests.swift
└── Contract/                         (NEW)
    └── ClassificationContractTests.swift
```

**Structure Decision**: Single native macOS app structure. New classification feature adds dedicated Services/Classification/ and Services/NLP/ modules, integrates with existing DocumentTypeContext model and TextEnhancementService. Uses existing GRDB database infrastructure for classification logging. CreateML training will be a separate utility project (not part of main app bundle).

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/bash/update-agent-context.sh claude`
     **IMPORTANT**: Execute it exactly as specified above. Do not add or remove any arguments.
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
1. **Database Setup** (GRDB schema)
   - Create ClassificationLog table and indexes
   - Test database migrations

2. **Models** (from data-model.md entities)
   - TextClassification struct [P]
   - TextFeatures struct [P]
   - ClassificationLog GRDB model [P]
   - DocumentType enum extensions [P]

3. **Contract Tests** (from contracts/)
   - TextClassificationService contract tests
   - ClassificationLogger contract tests
   - All tests must FAIL initially (no implementation)

4. **Core Services** (implementing contracts)
   - ClassificationModelManager (model loading/caching)
   - FeatureExtractor (text feature extraction)
   - DominantCharacteristicAnalyzer (mixed signal resolution)
   - ClassificationLogger (database persistence)
   - TextClassificationService (main API)

5. **Integration** (from quickstart.md scenarios)
   - Integrate with DocumentTypeContext
   - Integrate with TextEnhancementService
   - Wire up in AppState

6. **Integration Tests** (from quickstart.md)
   - 6 scenario tests (message, email, code, social, search, document)
   - Mixed signals test
   - Performance tests (<10ms, <10MB)
   - Database persistence tests

7. **Training Utilities** (outside main app)
   - Create training data CSV generator
   - CreateML training script
   - Model validation script

**Ordering Strategy**:
- Phase 1: Database + Models (all [P] parallel)
- Phase 2: Contract tests (all [P] parallel - must fail)
- Phase 3: Core services (dependency order: ModelManager → FeatureExtractor → Analyzer → Logger → Service)
- Phase 4: Integration (sequential: Context → Enhancement → AppState)
- Phase 5: Integration tests + validation

**Dependencies**:
- Models have no dependencies (can run in parallel)
- Contract tests depend on models
- Services depend on contract tests existing (TDD)
- Integration depends on services passing contract tests
- Integration tests depend on integration complete

**Estimated Output**: 30-35 numbered, dependency-ordered tasks in tasks.md

**Parallelization Opportunities**:
- [P] Models creation (4 files)
- [P] Contract test files (2 services)
- [P] Feature extraction + analysis (independent algorithms)

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

No violations - all constitutional principles satisfied.

## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command) - research.md created
- [x] Phase 1: Design complete (/plan command) - data-model.md, contracts/, quickstart.md, CLAUDE.md updated
- [x] Phase 2: Task planning complete (/plan command - approach described)
- [x] Phase 3: Tasks generated (/tasks command) - tasks.md created with 35 numbered tasks
- [ ] Phase 4: Implementation complete - NEXT STEP: Execute tasks.md
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS (all 7 principles + security/performance)
- [x] Post-Design Constitution Check: PASS (no new violations introduced)
- [x] All NEEDS CLARIFICATION resolved (1 deferred: multi-language support, low-impact)
- [x] Complexity deviations documented (none)

**Artifacts Generated**:
- [x] /specs/003-apple-s-naturallanguage/plan.md (this file)
- [x] /specs/003-apple-s-naturallanguage/research.md
- [x] /specs/003-apple-s-naturallanguage/data-model.md
- [x] /specs/003-apple-s-naturallanguage/contracts/TextClassificationService.md
- [x] /specs/003-apple-s-naturallanguage/contracts/ClassificationLogger.md
- [x] /specs/003-apple-s-naturallanguage/quickstart.md
- [x] /specs/003-apple-s-naturallanguage/tasks.md (35 numbered tasks)
- [x] /CLAUDE.md (updated with new technologies)

---
*Based on Constitution v1.0.0 - See `.specify/memory/constitution.md`*
