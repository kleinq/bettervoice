# Feature Specification: LLM Prompt Editor in Settings

**Feature Branch**: `004-allow-editing-of`
**Created**: 2025-10-06
**Status**: Draft
**Input**: User description: "allow editing of the LLM prompts in settings view. Enable the user to view the current LLM prompts, enter their own prompts, reset back to the default prompts."

## Execution Flow (main)
```
1. Parse user description from Input
   → Feature: LLM prompt customization in settings
2. Extract key concepts from description
   → Actors: Users (app users)
   → Actions: View prompts, edit prompts, reset to defaults
   → Data: LLM prompts (system prompts for different document types)
   → Constraints: Must preserve default prompts for reset functionality
3. For each unclear aspect:
   → [NEEDS CLARIFICATION: Should users be able to edit prompts for all document types or only specific ones?]
   → [NEEDS CLARIFICATION: Should prompt changes apply immediately or require app restart?]
   → [NEEDS CLARIFICATION: Should there be validation on prompt content?]
   → [NEEDS CLARIFICATION: Should users be able to export/import custom prompts?]
4. Fill User Scenarios & Testing section
   → User flow: Settings → View prompts → Edit → Save/Reset
5. Generate Functional Requirements
   → Each requirement must be testable
   → Mark ambiguous requirements
6. Identify Key Entities (if data involved)
   → LLM Prompt configurations per document type
7. Run Review Checklist
   → WARN "Spec has uncertainties - see NEEDS CLARIFICATION markers"
8. Return: SUCCESS (spec ready for planning after clarifications)
```

---

## ⚡ Quick Guidelines
- ✅ Focus on WHAT users need and WHY
- ❌ Avoid HOW to implement (no tech stack, APIs, code structure)
- 👥 Written for business stakeholders, not developers

---

## Clarifications

### Session 2025-10-06
- Q: When a user saves a custom prompt, should it apply immediately to future transcriptions or require an app restart? → A: Apply immediately - next transcription uses new prompt
- Q: Should empty prompts be allowed when saving, or must they contain text? → A: Allow empty - use default prompt as fallback
- Q: If a custom prompt causes LLM errors during enhancement, what should the system do? → A: Auto-fallback to default - silently use default prompt and log error
- Q: Should there be a maximum character limit for custom prompts? → A: No limit - allow any length prompt
- Q: Can users edit prompts while a voice transcription/enhancement is actively running? → A: Allow but warn - "Changes won't apply to current operation"

---

## User Scenarios & Testing *(mandatory)*

### Primary User Story
As a BetterVoice user, I want to customize the LLM prompts used for text enhancement so that I can tailor the output style to my specific needs and preferences. I should be able to view what prompts are currently being used, modify them to match my communication style, and reset them back to defaults if my changes don't work as expected.

### Acceptance Scenarios
1. **Given** the user opens the Settings view, **When** they navigate to the LLM prompts section, **Then** they should see a list of all current prompts organized by document type (email, message, document, social, code, search)

2. **Given** the user is viewing a specific prompt, **When** they click edit, **Then** they should be able to modify the prompt text in a text editor interface

3. **Given** the user has modified a prompt, **When** they save their changes, **Then** the new prompt should be used immediately for all subsequent text enhancement operations for that document type (without requiring app restart)

4. **Given** the user has customized one or more prompts, **When** they click "Reset to Default" for a specific prompt, **Then** that prompt should revert to the original system default

5. **Given** the user has customized prompts, **When** they click "Reset All to Defaults", **Then** all prompts should revert to their original system defaults

6. **Given** the user is viewing the current prompts, **When** no customizations have been made, **Then** each prompt should be clearly labeled as "Default"

7. **Given** an enhancement operation is in progress, **When** the user edits and saves a prompt, **Then** the system should display a warning message "Changes will apply to the next operation" and allow the save to proceed

### Edge Cases
- When a user saves an empty prompt, the system treats it as "use default" and applies the default prompt for that document type
- The system allows custom prompts of any length without imposing character limits; performance implications are handled by the LLM API
- When a custom prompt causes LLM errors during enhancement, the system automatically falls back to the default prompt, logs the error, and continues processing without interrupting the user
- Users can edit prompts during active enhancement operations, but the system warns that changes will only apply to the next operation (current operation uses the previous prompt)

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: System MUST display all current LLM prompts organized by document type (email, message, document, social, code, search, unknown)
- **FR-002**: System MUST allow users to view the complete text of each prompt
- **FR-003**: System MUST allow users to edit the text of any prompt
- **FR-004**: System MUST persist custom prompts across app restarts
- **FR-005**: System MUST provide a "Reset to Default" option for each individual prompt
- **FR-006**: System MUST provide a "Reset All to Defaults" option to restore all prompts at once
- **FR-007**: System MUST clearly indicate which prompts are using default values vs. custom values
- **FR-008**: System MUST use custom prompts (when set) for all text enhancement operations immediately after saving (no app restart required)
- **FR-009**: System MUST preserve original default prompts to enable reset functionality
- **FR-010**: Users MUST be able to access the prompt editor from the Settings view
- **FR-011**: System MUST allow saving empty prompts and treat them as "use default prompt" (effectively resetting to default behavior without explicit reset action)
- **FR-013**: System MUST allow custom prompts of any length without imposing character limits
- **FR-012**: System MUST automatically fallback to the default prompt when a custom prompt causes LLM errors, log the error for debugging, and continue the enhancement operation without user interruption
- **FR-014**: System MUST allow users to edit prompts while an enhancement operation is in progress, but MUST warn them that changes will only apply to subsequent operations (not the current one)

### Key Entities *(include if feature involves data)*
- **LLM Prompt**: Represents the text template sent to the LLM for enhancement, associated with a specific document type (email, message, etc.), has both a default value (immutable) and a custom value (user-editable, optional)
- **Document Type**: Categories of text that require different enhancement styles (email, message, document, social, code, search, unknown), each linked to one LLM prompt
- **Prompt Customization**: User preference that overrides default prompt for a specific document type, can be reset to restore default behavior

---

## Review & Acceptance Checklist
*GATE: Automated checks run during main() execution*

### Content Quality
- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

### Requirement Completeness
- [ ] No [NEEDS CLARIFICATION] markers remain
- [ ] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Scope is clearly bounded
- [ ] Dependencies and assumptions identified

---

## Execution Status
*Updated by main() during processing*

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked
- [x] User scenarios defined
- [x] Requirements generated
- [x] Entities identified
- [ ] Review checklist passed (pending clarifications)

---

## Notes for Planning Phase

**Key Clarifications Needed Before Implementation:**
1. Validation rules for custom prompts (empty, length limits, content restrictions)
2. Error handling strategy for malformed prompts
3. Whether changes apply immediately or require restart
4. Whether to support export/import of custom prompt sets
5. Whether users can edit all document types or only certain ones
6. UI/UX considerations for text editing (simple textarea vs. rich editor)

**Current State Understanding:**
- LLM prompts are currently defined in `DocumentTypeContext.swift` as computed properties
- Email prompt was recently updated with detailed iterative improvement instructions
- Claude API integration expects prompts with `{{TEXT}}` placeholder
- Different document types (email, message, document, social, code, search) have different default prompts

**Assumptions:**
- Custom prompts should use the same `{{TEXT}}` placeholder format as defaults
- Prompt customization is per-document-type, not per-user (single-user app assumption)
- Settings UI already has tab structure that can accommodate new prompt editor section
