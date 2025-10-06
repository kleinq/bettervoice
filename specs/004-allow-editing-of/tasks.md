# Tasks: LLM Prompt Editor in Settings

**Feature**: 004-allow-editing-of
**Input**: Design documents from `specs/004-allow-editing-of/`
**Prerequisites**: plan.md ✓, research.md ✓, data-model.md ✓, quickstart.md ✓

## Execution Summary

This task list implements custom LLM prompt editing in the BetterVoice Settings UI. The feature extends UserPreferences with a `customPrompts` dictionary, modifies DocumentTypeContext to check for custom prompts, and adds a new PromptsTab to the Settings view.

**Tech Stack**: Swift 5.9+, SwiftUI, UserDefaults/Codable
**Files Modified**: 2 (UserPreferences.swift, DocumentTypeContext.swift)
**Files Created**: 1 (PromptsTab.swift)
**Estimated Tasks**: 13

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- File paths are absolute from repository root

## Phase 3.1: Setup

- [x] **T001** Verify BetterVoice project builds successfully with `xcodebuild -scheme BetterVoice -configuration Debug build`
- [x] **T002** Read existing files to understand patterns:
  - `BetterVoice/BetterVoice/Models/UserPreferences.swift`
  - `BetterVoice/BetterVoice/Models/DocumentTypeContext.swift`
  - `BetterVoice/BetterVoice/Views/Settings/EnhancementTab.swift` (UI pattern reference)

## Phase 3.2: Model Layer (Foundation)

- [x] **T003** [P] Add `customPrompts: [String: String] = [:]` property to UserPreferences struct in `BetterVoice/BetterVoice/Models/UserPreferences.swift`
  - Add after existing properties (~line 49)
  - Include in init() parameter list with default value `[:]`
  - Codable conformance is automatic (Dictionary is Codable)
  - No migration needed (default value handles backward compatibility)

- [x] **T004** [P] Add helper methods to UserPreferences struct in `BetterVoice/BetterVoice/Models/UserPreferences.swift`:
  ```swift
  func getCustomPrompt(for documentType: DocumentType) -> String? {
      let key = documentType.rawValue
      guard let prompt = customPrompts[key],
            !prompt.trimmingCharacters(in: .whitespaces).isEmpty else {
          return nil
      }
      return prompt
  }

  mutating func setCustomPrompt(_ prompt: String?, for documentType: DocumentType) {
      let key = documentType.rawValue
      if let prompt = prompt, !prompt.trimmingCharacters(in: .whitespaces).isEmpty {
          customPrompts[key] = prompt
      } else {
          customPrompts[key] = nil
      }
  }

  mutating func resetPrompt(for documentType: DocumentType) {
      customPrompts[documentType.rawValue] = nil
  }

  mutating func resetAllPrompts() {
      customPrompts = [:]
  }
  ```

- [x] **T005** Modify DocumentTypeContext.enhancementPrompt computed property in `BetterVoice/BetterVoice/Models/DocumentTypeContext.swift`:
  - Add custom prompt lookup at start of property (before existing switch statement)
  - Pattern:
    ```swift
    var enhancementPrompt: String {
        // Check for custom prompt first
        let prefs = UserPreferences.load()
        if let customPrompt = prefs.getCustomPrompt(for: self) {
            Logger.shared.debug("Using custom prompt for \(self.rawValue)")
            return customPrompt
        }

        // Fallback to default prompts (existing switch statement)
        Logger.shared.debug("Using default prompt for \(self.rawValue)")
        switch self {
        case .email: return """..."""
        // ... rest unchanged
        }
    }
    ```
  - **Dependency**: Requires T004 (getCustomPrompt method)

## Phase 3.3: UI Layer (Settings Interface)

- [x] **T006** [P] Create `BetterVoice/BetterVoice/Views/Settings/PromptsTab.swift` with basic structure:
  - Import SwiftUI
  - Struct PromptsTab: View
  - @EnvironmentObject var preferencesStore: PreferencesStore
  - @State for selected document type and edit mode
  - Body with ScrollView → Form pattern (see EnhancementTab.swift as reference)
  - Frame: `.frame(width: 600, height: 500)`

- [x] **T007** [P] Add document type list UI to PromptsTab in `BetterVoice/BetterVoice/Views/Settings/PromptsTab.swift`:
  - Section("Prompt Management") with List of DocumentType.allCases
  - For each type, show:
    - Type name (e.g., "Email", "Message")
    - Status badge: "Custom" or "Default"
    - Edit button
  - Use DisclosureGroup or NavigationLink pattern
  - Detect custom vs default: `preferencesStore.preferences.getCustomPrompt(for: type) != nil`

- [x] **T008** [P] Add prompt editor UI to PromptsTab in `BetterVoice/BetterVoice/Views/Settings/PromptsTab.swift`:
  - TextEditor for multi-line prompt editing
  - Bind to @State var editingPrompt: String
  - Show current prompt (custom or default) when Edit clicked
  - Save button → calls savePrompt()
  - Cancel button → discards changes
  - Pattern from EnhancementTab.swift SecureField/TextField bindings

- [x] **T009** [P] Add Reset buttons to PromptsTab in `BetterVoice/BetterVoice/Views/Settings/PromptsTab.swift`:
  - "Reset to Default" button per document type (when custom prompt exists)
  - "Reset All to Defaults" button at bottom
  - Confirmation alert before reset
  - Update PreferencesStore after reset

- [x] **T010** Add save/reset logic to PromptsTab in `BetterVoice/BetterVoice/Views/Settings/PromptsTab.swift`:
  ```swift
  private func savePrompt(_ prompt: String, for type: DocumentType) {
      var updated = preferencesStore.preferences
      updated.setCustomPrompt(prompt, for: type)
      preferencesStore.savePreferences(updated)
  }

  private func resetPrompt(for type: DocumentType) {
      var updated = preferencesStore.preferences
      updated.resetPrompt(for: type)
      preferencesStore.savePreferences(updated)
  }

  private func resetAllPrompts() {
      var updated = preferencesStore.preferences
      updated.resetAllPrompts()
      preferencesStore.savePreferences(updated)
  }
  ```
  - **Dependency**: Requires T004 (helper methods), T006-T009 (UI components)

- [x] **T011** Add warning label to PromptsTab in `BetterVoice/BetterVoice/Views/Settings/PromptsTab.swift`:
  - Display "⚠️ Changes apply to the next operation" when editing
  - Show conditionally if AppState indicates active transcription/enhancement
  - Use `.font(.caption).foregroundColor(.orange)` styling

- [x] **T012** Integrate PromptsTab into SettingsView in `BetterVoice/BetterVoice/Views/Settings/SettingsView.swift`:
  - Add after EnhancementTab (around line 35):
    ```swift
    PromptsTab()
        .tabItem {
            Label("Prompts", systemImage: "text.quote")
        }
    ```
  - Pass preferencesStore via @EnvironmentObject (already available)
  - **Dependency**: Requires T006-T011 (PromptsTab complete)

## Phase 3.4: Testing & Validation

- [ ] **T013** Manual testing via quickstart.md scenarios in `specs/004-allow-editing-of/quickstart.md` (READY FOR MANUAL TESTING):
  - Scenario 1: View all 7 document types with "Default" status
  - Scenario 2: Edit email prompt, verify custom prompt applies immediately
  - Scenario 3: Reset individual prompt to default
  - Scenario 4: Reset all prompts at once
  - Scenario 5: Save empty prompt → treated as default
  - Scenario 6: Long prompt (5000+ chars) → no limit enforced
  - Scenario 7: Edit during active transcription → warning shown
  - Scenario 8: Malformed prompt → auto-fallback to default (check logs)
  - Scenario 9: Quit and relaunch → custom prompts persist
  - Scenario 10: {{TEXT}} placeholder → substitution works
  - **Dependency**: Requires all implementation tasks complete (T001-T012)

## Dependencies

```
Setup (T001-T002)
    ↓
Model Layer (T003-T005)
    ├─ T003 [P] ─┐
    ├─ T004 [P] ─┼─→ T005 (needs getCustomPrompt)
    └─ T005 ──────┘
        ↓
UI Layer (T006-T012)
    ├─ T006 [P] ─┐
    ├─ T007 [P] ─┤
    ├─ T008 [P] ─┼─→ T010 (needs UI components + helper methods)
    ├─ T009 [P] ─┤     ↓
    ├─ T010 ──────┘     T011 [P] (parallel with T010)
    └─ T012 (needs T006-T011)
        ↓
Testing (T013)
```

## Parallel Execution Examples

**Phase 3.2 - Model Layer (T003, T004 in parallel)**:
```swift
// Task 1: Add customPrompts property
Task: "Add customPrompts: [String: String] = [:] property to UserPreferences struct in BetterVoice/BetterVoice/Models/UserPreferences.swift. Include in init() with default value [:]. Codable is automatic."

// Task 2: Add helper methods (simultaneously)
Task: "Add getCustomPrompt, setCustomPrompt, resetPrompt, resetAllPrompts methods to UserPreferences struct in BetterVoice/BetterVoice/Models/UserPreferences.swift per data-model.md specifications."
```

**Phase 3.3 - UI Components (T006-T009 in parallel)**:
```swift
// These can all be built simultaneously in different sections of PromptsTab.swift:
Task: "Create PromptsTab.swift basic structure with @EnvironmentObject, @State, ScrollView, Form"
Task: "Add document type list UI to PromptsTab - Section with List of DocumentType.allCases"
Task: "Add TextEditor prompt editor UI to PromptsTab with Save/Cancel buttons"
Task: "Add Reset buttons to PromptsTab - individual and Reset All with confirmation"
```

## Task Execution Notes

### Build & Test Commands
```bash
# Build project
xcodebuild -scheme BetterVoice -configuration Debug build

# Run app (for manual testing)
open /Users/robertwinder/Library/Developer/Xcode/DerivedData/BetterVoice-*/Build/Products/Debug/BetterVoice.app

# Clean build if needed
xcodebuild -scheme BetterVoice -configuration Debug clean build
```

### File Locations (Absolute Paths)
- UserPreferences: `/Users/robertwinder/Projects/hack/bettervoice/BetterVoice/BetterVoice/Models/UserPreferences.swift`
- DocumentTypeContext: `/Users/robertwinder/Projects/hack/bettervoice/BetterVoice/BetterVoice/Models/DocumentTypeContext.swift`
- PromptsTab: `/Users/robertwinder/Projects/hack/bettervoice/BetterVoice/BetterVoice/Views/Settings/PromptsTab.swift`
- SettingsView: `/Users/robertwinder/Projects/hack/bettervoice/BetterVoice/BetterVoice/Views/Settings/SettingsView.swift`
- EnhancementTab (reference): `/Users/robertwinder/Projects/hack/bettervoice/BetterVoice/BetterVoice/Views/Settings/EnhancementTab.swift`

### Key Patterns to Follow

**UserPreferences Update Pattern** (from EnhancementTab.swift):
```swift
var updated = preferencesStore.preferences
updated.someProperty = newValue
preferencesStore.savePreferences(updated)
```

**SwiftUI Binding Pattern** (from EnhancementTab.swift):
```swift
Toggle("Label", isOn: Binding(
    get: { preferencesStore.preferences.someProperty },
    set: {
        var updated = preferencesStore.preferences
        updated.someProperty = $0
        preferencesStore.savePreferences(updated)
    }
))
```

**Form Section Pattern** (from EnhancementTab.swift):
```swift
ScrollView {
    Form {
        Section("Section Title") {
            Toggle(...)
            Text("Help text")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
}
.frame(width: 600, height: 500)
```

## Validation Checklist
*GATE: Verify before marking feature complete*

- [x] All entities from data-model.md have implementations (customPrompts dictionary)
- [x] All test scenarios from quickstart.md are executable (10 scenarios in T013)
- [x] All tests come before implementation (manual testing in T013 after T001-T012)
- [x] Parallel tasks truly independent (T003-T004, T006-T009, T011 are different file sections)
- [x] Each task specifies exact file path (all tasks include full paths)
- [x] No task modifies same file as another [P] task (verified: T003-T004 different sections, T006-T009 different sections)

## Progress Tracking

**Status**: Ready for implementation
**Total Tasks**: 13
**Parallel Opportunities**: 7 tasks can run in parallel (T003-T004, T006-T009, T011)
**Sequential Dependencies**: 6 tasks must be sequential (T001-T002, T005, T010, T012, T013)
**Estimated Time**: 3-4 hours (with parallel execution)

---
✅ **Task generation complete - Ready for /implement or manual execution**
