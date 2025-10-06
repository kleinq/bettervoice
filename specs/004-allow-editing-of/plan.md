# Implementation Plan: LLM Prompt Editor in Settings

**Branch**: `004-allow-editing-of` | **Date**: 2025-10-06 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/004-allow-editing-of/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path ✓
2. Fill Technical Context (scan for NEEDS CLARIFICATION) ✓
3. Fill Constitution Check section (no constitution file found - skip) ✓
4. Evaluate Constitution Check section → No violations ✓
5. Execute Phase 0 → research.md ✓
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, CLAUDE.md update ✓
7. Re-evaluate Constitution Check section → No constitution to check ✓
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md) ✓
9. STOP - Ready for /tasks command ✓
```

## Summary

Enable users to customize LLM prompts for different document types (email, message, document, social, code, search) through the Settings view. Users can view current prompts, edit them with immediate effect, and reset to defaults individually or all at once. Custom prompts are persisted across app restarts and include automatic fallback to defaults on errors.

**Technical Approach**: Extend UserPreferences model to store custom prompts, add new PromptEditorTab to Settings UI, modify DocumentTypeContext to check for custom prompts before using defaults, implement save/reset logic with validation.

## Technical Context

**Language/Version**: Swift 5.9+ (targeting macOS 12.0+)
**Primary Dependencies**: SwiftUI, AppKit, GRDB.swift (SQLite), existing DocumentTypeContext
**Storage**: UserPreferences (JSON file via PreferencesStore.swift), fallback to in-memory if file errors
**Testing**: Manual testing via Settings UI, unit tests for prompt storage/retrieval logic
**Target Platform**: macOS 12.0+ (Apple Silicon and Intel)
**Project Type**: Single macOS app with Settings UI
**Performance Goals**: Instant prompt switching (<10ms), immediate application without restart
**Constraints**: Maintain backward compatibility with existing default prompts, preserve `{{TEXT}}` placeholder format
**Scale/Scope**: 7 document types (email, message, document, social, code, search, unknown), unlimited prompt length

## Constitution Check

*No constitution file found at `.specify/constitution.md` - skipping constitutional validation*

**Architecture Simplicity**: Feature adds a single Settings tab and extends existing UserPreferences model. No new architectural patterns required.

**Implementation Simplicity**: Leverages existing SwiftUI Settings structure, UserPreferences storage, and DocumentTypeContext prompt system. Minimal new code.

## Project Structure

### Documentation (this feature)
```
specs/004-allow-editing-of/
├── spec.md              # Feature specification (/specify command output) ✓
├── plan.md              # This file (/plan command output) ✓
├── research.md          # Phase 0 output ✓
├── data-model.md        # Phase 1 output ✓
├── quickstart.md        # Phase 1 output ✓
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)

```
BetterVoice/BetterVoice/
├── Models/
│   ├── DocumentTypeContext.swift      # [MODIFY] Add custom prompt lookup
│   └── UserPreferences.swift          # [MODIFY] Add customPrompts dictionary
│
├── Views/Settings/
│   ├── SettingsView.swift             # [MODIFY] Add PromptsTab to TabView
│   └── PromptsTab.swift               # [CREATE] New prompt editor UI
│
├── Services/Enhancement/
│   └── TextEnhancementService.swift   # [READ] No changes - uses DocumentTypeContext
│
└── Services/Storage/
    └── PreferencesStore.swift         # [READ] Existing persistence - no changes needed

tests/
└── unit/
    └── PromptCustomizationTests.swift # [CREATE] Test custom prompt storage/retrieval
```

**Structure Decision**: Single macOS app project following existing BetterVoice architecture. All code under `BetterVoice/BetterVoice/` with Models, Views, and Services separation. Settings UI already uses SwiftUI TabView pattern - adding PromptsTab follows existing conventions.

## Phase 0: Outline & Research

**No unknowns in Technical Context** - All technologies and approaches are already established in the codebase.

### Research Tasks

1. **Current Prompt System Architecture**
   - Location: `DocumentTypeContext.swift` lines 42-173
   - Current implementation: Computed property `enhancementPrompt` returns hardcoded strings
   - Integration: Used by `TextEnhancementService.swift` and `ClaudeAPIClient.swift`

2. **UserPreferences Storage Pattern**
   - Location: `UserPreferences.swift` + `PreferencesStore.swift`
   - Current structure: Codable struct with @AppStorage wrapper for persistence
   - Existing pattern: Simple key-value with JSON encoding

3. **Settings UI Architecture**
   - Location: `SettingsView.swift` with multiple *Tab.swift files
   - Current pattern: TabView with separate View files per tab
   - Example: `EnhancementTab.swift`, `ExternalLLMTab.swift`

**Output**: ✅ [research.md](research.md) - Complete

## Phase 1: Design & Contracts

*Prerequisites: research.md complete*

### Data Model Design

**Primary Entity**: Custom Prompt Configuration
- Storage: Dictionary in UserPreferences (`[String: String]` keyed by DocumentType.rawValue)
- Fields: documentType (key), customPrompt (value), default prompt (from DocumentTypeContext)
- Validation: None required (empty prompts valid per spec FR-011)
- State: Active custom prompt or nil (use default)

### API Contracts

**No external API contracts needed** - This is an internal UI feature with local storage.

**Internal Contracts**:

1. **UserPreferences Extension**
   ```swift
   // New property in UserPreferences
   var customPrompts: [String: String]  // [DocumentType.rawValue: customPrompt]

   // Helper methods
   func getPrompt(for type: DocumentType) -> String?
   func setPrompt(_ prompt: String?, for type: DocumentType)
   func resetPrompt(for type: DocumentType)
   func resetAllPrompts()
   ```

2. **DocumentTypeContext Extension**
   ```swift
   // Modified enhancementPrompt property
   var enhancementPrompt: String {
       // 1. Check for custom prompt in UserPreferences
       // 2. If empty or nil, return default prompt
       // 3. Validate {{TEXT}} placeholder exists
   }
   ```

### Test Scenarios

From spec acceptance scenarios:

1. **View all prompts by document type**
   - Test: SettingsView loads → PromptsTab displays 7 document types
   - Assert: Each type shows default prompt label

2. **Edit and save custom prompt**
   - Test: User edits email prompt → saves
   - Assert: UserPreferences.customPrompts["email"] updated
   - Assert: Next enhancement uses custom prompt

3. **Reset individual prompt**
   - Test: User resets email prompt
   - Assert: customPrompts["email"] = nil
   - Assert: Next enhancement uses default prompt

4. **Reset all prompts**
   - Test: User clicks "Reset All"
   - Assert: customPrompts = [:]
   - Assert: All enhancements use defaults

5. **Empty prompt handling**
   - Test: User saves empty string
   - Assert: Treated as nil (use default)

**Output**:
- ✅ [data-model.md](data-model.md) - Complete
- ✅ [quickstart.md](quickstart.md) - Complete
- ✅ CLAUDE.md update - Complete

## Phase 2: Task Planning Approach

*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:

1. **Model Layer** (Foundation)
   - Task 1: Extend UserPreferences with customPrompts dictionary [P]
   - Task 2: Add prompt getter/setter helper methods [P]
   - Task 3: Modify DocumentTypeContext.enhancementPrompt to check custom prompts

2. **UI Layer** (Settings Interface)
   - Task 4: Create PromptsTab.swift with document type list [P]
   - Task 5: Add text editor for prompt editing [P]
   - Task 6: Implement Reset/Reset All buttons [P]
   - Task 7: Add "Changes apply to next operation" warning label
   - Task 8: Integrate PromptsTab into SettingsView TabView

3. **Testing & Validation**
   - Task 9: Create unit tests for custom prompt storage
   - Task 10: Test immediate application (no restart)
   - Task 11: Test empty prompt fallback behavior
   - Task 12: Test error fallback behavior
   - Task 13: Manual testing via quickstart.md

**Ordering Strategy**:
- Models before UI (Tasks 1-3 before 4-8)
- Independent UI components marked [P] (4, 5, 6 can be built in parallel)
- Integration tasks last (8 after 4-7)
- Testing throughout (9-13)

**Estimated Output**: 13-15 numbered tasks in tasks.md

**Dependencies**:
- Task 3 depends on Tasks 1-2 (needs helper methods)
- Tasks 4-7 are independent [P]
- Task 8 depends on Tasks 4-7 (needs components)
- Tasks 9-13 depend on implementation complete

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation

*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)
**Phase 4**: Implementation (execute tasks.md following TDD approach)
**Phase 5**: Validation (manual testing via quickstart.md, verify all acceptance scenarios)

## Complexity Tracking

*No constitutional violations - this section intentionally left empty*

## Progress Tracking

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [x] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: N/A (no constitution file)
- [x] Post-Design Constitution Check: N/A
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (none)

---
✅ **/plan command complete - Ready for /tasks**

**Generated Artifacts**:
- [x] plan.md (this file)
- [x] research.md (technology decisions)
- [x] data-model.md (storage design)
- [x] quickstart.md (manual test scenarios)
- [x] CLAUDE.md (agent context updated)

**Next Command**: `/implement` - Execute tasks or manual implementation

**Tasks File**: ✅ [tasks.md](tasks.md) - 13 numbered tasks with 7 parallel opportunities
