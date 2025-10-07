# Research: LLM Prompt Editor

**Feature**: 004-allow-editing-of
**Created**: 2025-10-06

## Research Summary

All technologies and patterns are already established in the BetterVoice codebase. This feature leverages existing architecture with minimal new patterns required.

## Current Prompt System

**Location**: [DocumentTypeContext.swift](../../BetterVoice/BetterVoice/Models/DocumentTypeContext.swift) lines 42-173

**Current Implementation**:
```swift
var enhancementPrompt: String {
    switch self {
    case .email:
        return """
        You are a text reviewer and editor...
        [Full 119-line prompt]
        """
    case .message:
        return "[Shorter prompt for messages]"
    // ... 5 more cases
    }
}
```

**Decision**: Modify this computed property to check UserPreferences first before returning hardcoded defaults.

**Rationale**:
- Minimal code change (add 2-3 lines at start of property)
- Maintains backward compatibility (defaults unchanged)
- No performance impact (UserPreferences already in memory)
- Preserves existing error handling

**Alternatives Considered**:
- Create separate PromptManager service → Rejected: Unnecessary abstraction for simple lookup
- Store prompts in database → Rejected: UserPreferences JSON file sufficient, no query needs

**Integration Points**:
- Used by: `TextEnhancementService.swift` (line 70+) via `documentType.enhancementPrompt`
- Used by: `ClaudeAPIClient.swift` for API requests
- No changes needed to consumers - transparent lookup

## UserPreferences Storage

**Location**:
- Model: [UserPreferences.swift](../../BetterVoice/BetterVoice/Models/UserPreferences.swift)
- Service: [PreferencesStore.swift](../../BetterVoice/BetterVoice/Services/Storage/PreferencesStore.swift)

**Current Pattern**:
```swift
struct UserPreferences: Codable {
    var hotkeyKeyCode: UInt32
    var selectedModelSize: WhisperModelSize
    // ... 20+ properties

    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        }
    }

    static func load() -> UserPreferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return UserPreferences() // Return defaults
        }
        return decoded
    }
}
```

**Decision**: Add `var customPrompts: [String: String] = [:]` property to UserPreferences.

**Rationale**:
- Dictionary keys = DocumentType.rawValue ("email", "message", etc.)
- Values = custom prompt text or empty string (treated as nil)
- Codable conformance automatic (Dictionary is Codable)
- Migration safe (new property has default value)
- No database schema needed

**Alternatives Considered**:
- Separate PromptPreferences struct → Rejected: Adds complexity, UserPreferences already handles similar data
- CoreData/GRDB storage → Rejected: No relational queries needed, JSON file simpler
- Individual properties (emailPrompt, messagePrompt...) → Rejected: Not scalable, dictionary cleaner

**Storage Format Example**:
```json
{
  "customPrompts": {
    "email": "Custom email enhancement prompt...",
    "message": "",  // Empty = use default
    "document": "Custom document prompt..."
  }
}
```

## Settings UI Architecture

**Location**: [SettingsView.swift](../../BetterVoice/BetterVoice/Views/Settings/SettingsView.swift)

**Current Pattern**:
```swift
TabView {
    GeneralSettingsView()
        .tabItem { Label("General", systemImage: "gear") }

    AudioFeedbackTab()
        .tabItem { Label("Audio Feedback", systemImage: "speaker.wave.2") }

    ModelSettingsView()
        .tabItem { Label("Models", systemImage: "cpu") }

    EnhancementTab()
        .tabItem { Label("Enhancement", systemImage: "wand.and.stars") }
}
.frame(width: 700, height: 500)
```

**Decision**: Add new `PromptsTab()` after EnhancementTab.

**Rationale**:
- Follows existing pattern (separate View file per tab)
- Icon: "text.quote" (represents text/prompts)
- Tab title: "Prompts"
- Size: Can use EnhancementTab as template (500x400)

**Reference Implementation**: [EnhancementTab.swift](../../BetterVoice/BetterVoice/Views/Settings/EnhancementTab.swift)

**UI Components Needed**:
- `List` or `ForEach` over DocumentType.allCases
- `TextEditor` for prompt editing (multi-line)
- `Button` for "Reset" per prompt
- `Button` for "Reset All"
- `Text` label showing "Default" vs "Custom"
- `Text` warning: "Changes apply to next operation"

**Best Practices from EnhancementTab**:
```swift
// Pattern 1: Binding to nested UserPreferences property
Toggle("Enable feature", isOn: Binding(
    get: { preferencesStore.preferences.someProperty },
    set: {
        var updated = preferencesStore.preferences
        updated.someProperty = $0
        preferencesStore.savePreferences(updated)
    }
))

// Pattern 2: Form with Sections
Form {
    Section("Section Title") {
        Toggle(...)
        Text("Help text").font(.caption).foregroundColor(.secondary)
    }
}

// Pattern 3: ScrollView wrapper for overflow
ScrollView {
    Form { ... }
}
.frame(width: 500, height: 400)
```

**Decision for PromptsTab**: Use List with disclosure groups per document type, TextEditor for editing.

## Validation & Error Handling

**Requirement**: No validation needed (per spec FR-011, FR-013)

**Decision**:
- Allow empty prompts → treat as nil
- Allow unlimited length → no character limit
- No {{TEXT}} placeholder validation → LLM will fail naturally, fallback to default

**Error Fallback** (FR-012):
Current error handling in ClaudeAPIClient already catches API errors. Need to add:
```swift
catch {
    Logger.shared.error("Custom prompt failed, falling back to default")
    // Retry with default prompt
    return try await enhance(text, with: documentType.defaultPrompt)
}
```

**Rationale**: Transparent to user, logged for debugging, prevents workflow interruption.

## Performance Considerations

**Lookup Performance**:
- Dictionary lookup: O(1)
- UserPreferences already in memory (loaded at launch)
- No disk I/O on hot path

**Memory**:
- 7 prompts × ~500 chars avg = ~3.5 KB
- Email prompt (longest) = ~4 KB
- Total impact: <30 KB worst case

**Decision**: No optimization needed, performance already exceeds target (<10ms).

## Migration & Compatibility

**Backward Compatibility**:
- New property has default value `= [:]`
- Old UserPreferences JSON deserializes correctly (missing field = default)
- No migration script needed

**Forward Compatibility**:
- If feature removed, unused customPrompts field ignored
- No breaking changes to UserPreferences structure

## Testing Strategy

**Unit Tests**:
- Test prompt storage/retrieval
- Test empty prompt → default fallback
- Test prompt persistence across app restart

**Manual Tests** (quickstart.md):
1. View default prompts
2. Edit email prompt
3. Verify transcription uses custom prompt
4. Reset prompt → verify default restored
5. Test during active transcription → verify warning

**No Contract Tests**: Internal feature, no external APIs.

## Summary

**Technologies Used**:
- Swift 5.9 UserDefaults + Codable (existing)
- SwiftUI Form, List, TextEditor (existing)
- UserPreferences storage pattern (existing)

**New Code Required**:
1. Extend UserPreferences with `customPrompts: [String: String]`
2. Add 3-5 helper methods (getPrompt, setPrompt, reset)
3. Modify DocumentTypeContext.enhancementPrompt (3-4 lines)
4. Create PromptsTab.swift (~200-250 lines)
5. Add tab to SettingsView (3 lines)

**Estimated Complexity**: Low (all patterns established, minimal new logic)

---
*Research complete - no unknowns remaining*
