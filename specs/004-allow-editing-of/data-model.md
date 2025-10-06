# Data Model: LLM Prompt Customization

**Feature**: 004-allow-editing-of
**Created**: 2025-10-06

## Overview

Custom LLM prompts are stored in the existing UserPreferences model as a simple dictionary. No new database tables, no schema migrations, no complex relationships.

## Entity: Custom Prompt Configuration

**Storage**: Dictionary property in UserPreferences struct
**Persistence**: UserDefaults via JSONEncoder (existing pattern)
**Lifetime**: Persists across app restarts until user resets

### Schema

```swift
struct UserPreferences: Codable {
    // ... existing 20+ properties ...

    // NEW: Custom prompts keyed by document type
    var customPrompts: [String: String] = [:]

    // Key = DocumentType.rawValue ("email", "message", "document", "social", "code", "search", "unknown")
    // Value = Custom prompt text (String)
    // Empty or nil = Use default prompt from DocumentTypeContext
}
```

### Example Data

**JSON Representation**:
```json
{
  "customPrompts": {
    "email": "You are a professional email writer. Transform the following text into a clear, concise email:\n\n{{TEXT}}",
    "message": "",
    "document": "Format the following text as a formal document:\n\n{{TEXT}}"
  }
}
```

**Interpretation**:
- "email": Custom prompt (user-defined)
- "message": Empty string → use default prompt
- "document": Custom prompt (user-defined)
- "social", "code", "search", "unknown": Not in dict → use default prompts

## Data Access Patterns

### Read Pattern (Hot Path - Enhancement Flow)

```swift
// In DocumentTypeContext.swift
var enhancementPrompt: String {
    // 1. Check for custom prompt
    let prefs = UserPreferences.load()
    if let customPrompt = prefs.customPrompts[self.rawValue],
       !customPrompt.trimmingCharacters(in: .whitespaces).isEmpty {
        return customPrompt
    }

    // 2. Fallback to default (existing switch statement)
    switch self {
    case .email: return "[default email prompt]"
    // ...
    }
}
```

**Performance**:
- Dictionary lookup: O(1)
- UserPreferences already cached in memory
- No disk I/O on hot path
- Total overhead: <1ms

### Write Pattern (Settings UI)

```swift
// In PromptsTab.swift
func saveCustomPrompt(_ prompt: String, for type: DocumentType) {
    var prefs = UserPreferences.load()

    let trimmed = prompt.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty {
        // Empty = reset to default
        prefs.customPrompts[type.rawValue] = nil
    } else {
        prefs.customPrompts[type.rawValue] = trimmed
    }

    prefs.save()
    preferencesStore.preferences = prefs  // Trigger UI update
}
```

**Frequency**: Rare (user editing settings)
**Performance**: <10ms (JSON encode + UserDefaults write)

### Reset Pattern

```swift
// Reset single prompt
func resetPrompt(for type: DocumentType) {
    var prefs = UserPreferences.load()
    prefs.customPrompts[type.rawValue] = nil
    prefs.save()
}

// Reset all prompts
func resetAllPrompts() {
    var prefs = UserPreferences.load()
    prefs.customPrompts = [:]
    prefs.save()
}
```

## Validation Rules

**None** - Per spec requirements:
- FR-011: Empty prompts allowed → treated as "use default"
- FR-013: No character limit → any length accepted
- No {{TEXT}} validation → LLM will fail naturally, fallback to default (FR-012)

## State Diagram

```
┌─────────────┐
│   Default   │  (No entry in customPrompts dict)
│   Prompt    │
└──────┬──────┘
       │
       │ User edits prompt
       ▼
┌─────────────┐
│   Custom    │  (customPrompts["email"] = "...")
│   Prompt    │
└──────┬──────┘
       │
       │ User saves empty / clicks Reset
       ▼
┌─────────────┐
│   Default   │  (customPrompts["email"] = nil)
│   Prompt    │
└─────────────┘
```

**States**:
1. **Default** (initial): `customPrompts[type]` = nil or missing → use DocumentTypeContext default
2. **Custom**: `customPrompts[type]` = non-empty string → use custom prompt
3. **Explicitly Reset**: `customPrompts[type]` = nil → back to default

**Transitions**:
- Default → Custom: User saves non-empty prompt
- Custom → Default: User saves empty prompt OR clicks Reset button
- Custom → Custom: User edits existing custom prompt

## Relationships

**No relationships** - This is a simple key-value store.

```
UserPreferences (1) ──has─→ (0..*) CustomPrompts
                            ↓
                    Dictionary [String: String]
                    - Key: DocumentType.rawValue
                    - Value: Custom prompt text
```

## Default Values

**Source of Truth**: [DocumentTypeContext.swift](../../BetterVoice/BetterVoice/Models/DocumentTypeContext.swift) lines 42-173

**Default Prompts by Type**:

| Document Type | Prompt Length | Key Features |
|--------------|---------------|--------------|
| email | ~4000 chars | Iterative improvement, scoring rubric, casual detection |
| message | ~200 chars | Conversational, short lines, casual tone |
| document | ~200 chars | Formal grammar, paragraphs, professional |
| social | ~200 chars | Engaging, concise, character limits |
| code | ~200 chars | Technical terms, minimal formatting |
| search | ~150 chars | Keyword-focused, no punctuation |
| unknown | ~150 chars | Basic grammar and punctuation |

**Preservation**: Default prompts remain hardcoded in DocumentTypeContext - never modified.

## Migration & Compatibility

**Adding customPrompts Property**:
```swift
// Before (old UserPreferences)
{
  "hotkeyKeyCode": 15,
  "selectedModelSize": "base",
  ...
}

// After (new UserPreferences - backward compatible)
{
  "hotkeyKeyCode": 15,
  "selectedModelSize": "base",
  ...,
  "customPrompts": {}  // ← Default value if missing
}
```

**Codable Automatic Handling**:
- Decoding old JSON: Missing `customPrompts` field → uses default value `[:]`
- Encoding new JSON: Always includes `customPrompts` (even if empty)

**No Migration Script Needed**: Swift Codable + default value = automatic migration.

## Performance Characteristics

**Memory Footprint**:
- 7 document types × 500 chars avg = ~3.5 KB
- Email prompt (longest possible) = ~4 KB
- Total worst case: <30 KB
- Impact: Negligible (UserPreferences already ~2 KB)

**Lookup Performance**:
- Dictionary access: O(1)
- No parsing, no computation
- UserPreferences cached in memory
- Zero disk I/O on enhancement hot path

**Storage Performance**:
- Write frequency: Rare (user editing settings)
- Write latency: <10ms (JSON encode + UserDefaults write)
- No background syncing, no async operations

## Data Integrity

**Consistency**:
- Single source of truth (UserDefaults)
- Atomic writes (UserDefaults handles concurrency)
- No cache invalidation needed

**Error Handling**:
- If UserDefaults corrupted → UserPreferences.load() returns defaults
- If customPrompts malformed → Dictionary decode fails → empty dict
- If custom prompt causes LLM error → fallback to default (FR-012)

**Backup/Restore**:
- UserDefaults backed up via iCloud/Time Machine
- Export: UserPreferences.save() → JSON file
- Import: JSONDecoder → UserPreferences → .save()

## Test Data Examples

### Minimal (No Customizations)
```swift
UserPreferences(
    // ... standard defaults ...
    customPrompts: [:]  // No custom prompts
)
```

### Partial Customization
```swift
UserPreferences(
    customPrompts: [
        "email": "Short email prompt for testing",
        "message": "Custom message prompt"
    ]
)
// "document", "social", etc. → use defaults
```

### Full Customization
```swift
UserPreferences(
    customPrompts: [
        "email": "Custom email prompt...",
        "message": "Custom message prompt...",
        "document": "Custom document prompt...",
        "social": "Custom social prompt...",
        "code": "Custom code prompt...",
        "search": "Custom search prompt...",
        "unknown": ""  // Empty → use default
    ]
)
```

---
*Data model complete - ready for implementation*
