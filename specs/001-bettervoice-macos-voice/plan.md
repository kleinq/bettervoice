
# Implementation Plan: BetterVoice Voice Transcription App

**Branch**: `001-bettervoice-macos-voice` | **Date**: 2025-09-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/Users/robertwinder/Projects/hack/bettervoice/specs/001-bettervoice-macos-voice/spec.md`

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

BetterVoice is a native macOS menu bar application that provides hotkey-activated voice transcription using local Whisper models (whisper.cpp). The app captures audio via press-and-hold hotkey, transcribes speech locally without internet, applies intelligent text enhancement based on document context (email, message, document, search), and automatically pastes formatted text into the active application. Optional cloud API enhancement (Claude/OpenAI) provides advanced formatting. The system includes a learning component that adapts to user editing patterns over time.

**Technical Approach**: Native SwiftUI app with C++ whisper.cpp bridge, AVFoundation audio capture, Carbon/CGEvent hotkey handling, NSWorkspace for app detection, GRDB for SQLite learning database, and URLSession for optional cloud APIs.

## Technical Context

**Language/Version**: Swift 5.9+ (targeting macOS 12.0+)
**Primary Dependencies**: SwiftUI, AppKit, AVFoundation, whisper.cpp (C++ bridge), GRDB.swift (SQLite), Carbon Events API
**Storage**: SQLite (GRDB) for learning patterns, CoreData optional for transcription history, file-based for Whisper models
**Testing**: XCTest (unit, integration, UI tests), Quick/Nimble (optional BDD), XCUITest for E2E
**Target Platform**: macOS 12.0 (Monterey) or later, Apple Silicon + Intel x64
**Project Type**: single (native macOS app)
**Performance Goals**: <100ms hotkey response, <3s transcription (30s audio, base model), <16ms frame time (60fps UI), <2s app launch
**Constraints**: <50% sustained CPU, <200MB typical memory (500MB max), <2 hour max recording, offline-capable for core features
**Scale/Scope**: Single-user desktop app, ~15 SwiftUI views, ~30 model/service classes, ~5 Whisper model sizes, 2 cloud API integrations

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Privacy-First Architecture ✅ PASS
- **Requirement**: All user data remains local by default, no transmission without explicit consent
- **Compliance**: Audio stored temporarily in sandboxed container, deleted after transcription. Learning data stays local in SQLite. Cloud APIs are optional and require explicit enablement.
- **Evidence**: FR-016 (delete audio), SR-001 (local data), SR-004 (no external transmission), SR-006 (explicit opt-in)

### II. Local-First Processing ✅ PASS
- **Requirement**: Core transcription using local whisper.cpp, functional offline, cloud as optional layer
- **Compliance**: Whisper.cpp integration provides full offline transcription. Cloud APIs only enhance, not replace core functionality.
- **Evidence**: FR-003 (local transcription), FR-020 (optional cloud), SR-001 (local by default)

### III. Native Platform Integration ✅ PASS
- **Requirement**: Native macOS frameworks (SwiftUI, AppKit, AVFoundation), Apple HIG, platform-standard APIs
- **Compliance**: All UI in SwiftUI, menu bar via AppKit, audio via AVFoundation, permissions via macOS APIs, hotkeys via Carbon/CGEvent
- **Evidence**: Technical Context specifies SwiftUI, AppKit, AVFoundation, Carbon Events

### IV. Test-Driven Development (NON-NEGOTIABLE) ✅ PASS
- **Requirement**: Tests written before implementation, Red-Green-Refactor cycle enforced
- **Compliance**: Plan Phase 1 generates contract tests that must fail before implementation. Integration tests precede implementation tasks.
- **Evidence**: Phase 1 step 3 (contract tests must fail), Phase 2 ordering (tests before implementation)

### V. Performance & Resource Efficiency ✅ PASS
- **Requirement**: <16ms frame time, <50% CPU sustained, <200MB memory typical
- **Compliance**: Performance requirements match constitutional standards exactly
- **Evidence**: PR-008 (<16ms frame time), FR-027 (<50% CPU), FR-028 (<200MB memory), PR-004 (<2s launch)

### VI. Optional Cloud Enhancement ✅ PASS
- **Requirement**: Cloud APIs optional, app functional without keys, clear communication of active status
- **Compliance**: External LLM explicitly optional, clear UI feedback required, enable/disable per-session
- **Evidence**: FR-020 (optional LLM), FR-011 (status display), SR-006 (explicit opt-in)

### VII. User Control & Transparency ✅ PASS
- **Requirement**: Transparent behavior, visible processing status, user control over settings, actionable errors
- **Compliance**: Menu bar status indicators, overlay feedback, configurable settings, non-technical errors
- **Evidence**: FR-013 (menu bar status), FR-010/FR-011 (visual feedback), FR-012 (hotkey config), UR-003 (actionable errors)

**Initial Gate Result**: ✅ ALL PRINCIPLES SATISFIED - Proceed to Phase 0

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
BetterVoice/                           # Xcode project root
├── BetterVoice/                       # Main app target
│   ├── App/
│   │   ├── BetterVoiceApp.swift      # App entry point
│   │   └── AppState.swift             # Global app state
│   ├── Views/
│   │   ├── MenuBar/
│   │   │   ├── MenuBarView.swift     # Menu bar UI
│   │   │   └── StatusIconView.swift
│   │   ├── Settings/
│   │   │   ├── SettingsWindow.swift  # Settings window container
│   │   │   ├── RecordingTab.swift
│   │   │   ├── TranscriptionTab.swift
│   │   │   ├── EnhancementTab.swift
│   │   │   ├── ExternalLLMTab.swift
│   │   │   ├── AdvancedTab.swift
│   │   │   └── PermissionsTab.swift
│   │   ├── Overlays/
│   │   │   ├── RecordingOverlay.swift
│   │   │   └── ProcessingOverlay.swift
│   │   └── Components/
│   │       ├── WaveformView.swift
│   │       └── ProgressIndicatorView.swift
│   ├── Models/
│   │   ├── AudioRecording.swift
│   │   ├── TranscriptionJob.swift
│   │   ├── EnhancedText.swift
│   │   ├── DocumentTypeContext.swift
│   │   ├── LearningPattern.swift
│   │   ├── WhisperModel.swift
│   │   ├── UserPreferences.swift
│   │   └── ExternalLLMConfig.swift
│   ├── Services/
│   │   ├── Audio/
│   │   │   ├── AudioCaptureService.swift
│   │   │   └── AudioProcessingService.swift
│   │   ├── Transcription/
│   │   │   ├── WhisperService.swift          # whisper.cpp bridge
│   │   │   ├── ModelDownloadService.swift
│   │   │   └── TranscriptionQueue.swift
│   │   ├── Enhancement/
│   │   │   ├── TextEnhancementService.swift
│   │   │   ├── DocumentTypeDetector.swift
│   │   │   ├── FillerWordRemover.swift
│   │   │   └── FormatApplier.swift
│   │   ├── Learning/
│   │   │   ├── LearningService.swift
│   │   │   ├── PatternRecognizer.swift
│   │   │   └── ClipboardMonitor.swift
│   │   ├── Cloud/
│   │   │   ├── ClaudeAPIClient.swift
│   │   │   ├── OpenAIAPIClient.swift
│   │   │   └── LLMEnhancementService.swift
│   │   ├── System/
│   │   │   ├── HotkeyManager.swift           # Carbon Events
│   │   │   ├── PasteService.swift            # CGEvent
│   │   │   ├── AppDetectionService.swift     # NSWorkspace
│   │   │   └── PermissionsManager.swift
│   │   └── Storage/
│   │       ├── DatabaseManager.swift         # GRDB
│   │       ├── PreferencesStore.swift
│   │       └── ModelStorage.swift
│   ├── Utilities/
│   │   ├── Logger.swift
│   │   ├── ErrorHandler.swift
│   │   └── KeychainHelper.swift
│   └── Resources/
│       ├── Sounds/                           # Audio cues
│       ├── Assets.xcassets/                  # Icons, images
│       └── Info.plist
├── whisper.cpp/                              # C++ bridge submodule
│   ├── include/
│   └── src/
├── BetterVoiceTests/
│   ├── Contract/
│   │   ├── AudioCaptureContractTests.swift
│   │   ├── TranscriptionContractTests.swift
│   │   ├── EnhancementContractTests.swift
│   │   └── PasteContractTests.swift
│   ├── Integration/
│   │   ├── EndToEndTranscriptionTests.swift
│   │   ├── LearningSystemTests.swift
│   │   ├── CloudAPIIntegrationTests.swift
│   │   └── HotkeyWorkflowTests.swift
│   └── Unit/
│       ├── Models/
│       ├── Services/
│       └── Utilities/
└── BetterVoiceUITests/
    ├── MenuBarUITests.swift
    ├── SettingsUITests.swift
    └── OverlayUITests.swift
```

**Structure Decision**: Native macOS single-project structure using standard Xcode conventions. SwiftUI views organized by feature (MenuBar, Settings, Overlays), models follow spec entities, services grouped by domain (Audio, Transcription, Enhancement, Learning, Cloud, System, Storage). whisper.cpp integrated as C++ bridge submodule with Swift wrapper. Tests organized into Contract (interface validation), Integration (cross-service), Unit (isolated logic), and UITests (end-to-end user flows).

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
1. **From Contracts** (3 contract files generated):
   - audio-capture-service.md → Contract test task [P]
   - whisper-service.md → Contract test task [P]
   - text-enhancement-service.md → Contract test task [P]
   - Plus additional contracts for: HotkeyManager, PasteService, DocumentTypeDetector, LearningService

2. **From Data Model** (8 entities defined):
   - AudioRecording → Model file + unit tests [P]
   - TranscriptionJob → Model file + unit tests [P]
   - EnhancedText → Model file + unit tests [P]
   - DocumentTypeContext → Model file + unit tests [P]
   - LearningPattern → Model file + GRDB schema + unit tests [P]
   - WhisperModel → Model file + unit tests [P]
   - UserPreferences → Model file + unit tests [P]
   - ExternalLLMConfig → Model file + unit tests [P]

3. **From Quickstart** (primary user scenario):
   - End-to-end integration test covering complete workflow
   - Per-phase integration tests (recording, transcription, enhancement, paste, learning)

4. **From Project Structure**:
   - Xcode project setup
   - whisper.cpp C++ bridge integration
   - SwiftUI views (15 files)
   - Service implementations (30 files)
   - GRDB database setup

**Ordering Strategy** (TDD-compliant):
1. **Setup Phase**: Xcode project, SPM dependencies (GRDB), whisper.cpp submodule
2. **Test Phase** (write all tests FIRST):
   - Contract tests (services) [P]
   - Unit tests (models) [P]
   - Integration tests (workflows)
3. **Model Phase**: Implement all 8 models to make unit tests pass [P]
4. **Service Phase** (dependency order):
   - Storage services (DatabaseManager, PreferencesStore)
   - Audio services (AudioCaptureService)
   - Transcription services (WhisperService, ModelDownloadService)
   - Enhancement services (TextEnhancementService, DocumentTypeDetector, FillerWordRemover)
   - Learning services (LearningService, ClipboardMonitor)
   - Cloud services (ClaudeAPIClient, OpenAIAPIClient) [P]
   - System services (HotkeyManager, PasteService, AppDetectionService, PermissionsManager)
5. **View Phase**: SwiftUI views (can work in parallel once services exist)
6. **Integration Phase**: Wire up components, resolve integration issues
7. **Polish Phase**: UI refinements, error handling, logging, performance tuning

**Estimated Output**: ~80-100 numbered, ordered tasks in tasks.md
- Setup: 5 tasks
- Tests: 25 tasks (contract + unit + integration)
- Models: 8 tasks
- Services: 30 tasks
- Views: 15 tasks
- Integration: 5 tasks
- Polish: 10 tasks

**Parallelization Opportunities**:
- All contract tests [P] (different files)
- All model creation [P] (different files)
- Cloud API clients [P] (Claude vs OpenAI)
- Settings tabs [P] (6 independent SwiftUI views)
- Unit test files [P] (independent)

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |


## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

**No constitutional violations** - All principles satisfied. See Constitution Check section above for evidence.

## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
  - ✅ research.md created with 10 research areas resolved
  - ✅ All technical decisions documented (whisper.cpp, hotkeys, document detection, enhancement pipeline, learning, cloud APIs, audio capture, performance, testing, dependencies)
- [x] Phase 1: Design complete (/plan command)
  - ✅ data-model.md created with 8 entities defined
  - ✅ contracts/ directory created with 3 service contracts
  - ✅ quickstart.md created with end-to-end user flow
  - ✅ CLAUDE.md updated with project context
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
  - ✅ Task generation strategy documented
  - ✅ Ordering strategy defined (TDD-compliant)
  - ✅ Estimated 80-100 tasks across 7 phases
  - ✅ Parallelization opportunities identified
- [ ] Phase 3: Tasks generated (/tasks command) - **NEXT STEP**
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS (all 7 principles satisfied)
- [x] Post-Design Constitution Check: PASS (re-validated after Phase 1, no new violations)
- [x] All NEEDS CLARIFICATION resolved (none existed in well-defined spec)
- [x] Complexity deviations documented (none - no violations)

**Artifacts Generated**:
- `/Users/robertwinder/Projects/hack/bettervoice/specs/001-bettervoice-macos-voice/plan.md` (this file)
- `/Users/robertwinder/Projects/hack/bettervoice/specs/001-bettervoice-macos-voice/research.md`
- `/Users/robertwinder/Projects/hack/bettervoice/specs/001-bettervoice-macos-voice/data-model.md`
- `/Users/robertwinder/Projects/hack/bettervoice/specs/001-bettervoice-macos-voice/quickstart.md`
- `/Users/robertwinder/Projects/hack/bettervoice/specs/001-bettervoice-macos-voice/contracts/audio-capture-service.md`
- `/Users/robertwinder/Projects/hack/bettervoice/specs/001-bettervoice-macos-voice/contracts/whisper-service.md`
- `/Users/robertwinder/Projects/hack/bettervoice/specs/001-bettervoice-macos-voice/contracts/text-enhancement-service.md`
- `/Users/robertwinder/Projects/hack/bettervoice/CLAUDE.md`

---
*Based on Constitution v1.0.0 - See `.specify/memory/constitution.md`*
