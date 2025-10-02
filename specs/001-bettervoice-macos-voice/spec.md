# Feature Specification: BetterVoice Voice Transcription App

**Feature Branch**: `001-bettervoice-macos-voice`
**Created**: 2025-09-30
**Status**: Draft
**Input**: User description: "BetterVoice macOS voice transcription app with hotkey recording, local Whisper processing, intelligent text enhancement, and optional cloud API integration"

## User Scenarios & Testing

### Primary User Story

A macOS user is typing an email in Gmail and needs to quickly insert a spoken passage. They press and hold the Right Option key while speaking for 15 seconds, then release. Within 3 seconds, their speech appears as properly formatted, punctuated text in the email field where their cursor was positioned. The text includes proper capitalization, removes filler words, and applies email-appropriate formatting such as paragraph breaks and professional tone.

### Acceptance Scenarios

1. **Given** the app is running and the user is focused on a text field in any application, **When** the user presses and holds the configured hotkey (default: Right Option key) and speaks for 10 seconds then releases the key, **Then** the spoken words appear as transcribed text in the text field within 3 seconds with proper punctuation and capitalization

2. **Given** the user is composing a message in Slack, **When** they record speech containing "um" and "like" filler words, **Then** the pasted text has these filler words removed and uses casual messaging tone

3. **Given** the user is typing in Google Docs, **When** they speak a bulleted list (e.g., "first item computers, second item keyboards, third item monitors"), **Then** the text is formatted as a proper numbered or bulleted list

4. **Given** external LLM enhancement is enabled and the user records speech, **When** the transcription completes, **Then** the text is further enhanced by the configured cloud API before pasting

5. **Given** the user pastes transcribed text and then manually edits it, **When** the clipboard content changes within 10 seconds of pasting, **Then** the system learns from the user's corrections and adapts future formatting

6. **Given** the user has recorded speech but the active application window cannot be determined, **When** transcription completes, **Then** the text is formatted using generic document formatting rules

7. **Given** the user selects a different Whisper model size (tiny, base, small, medium, large), **When** they record speech for the first time with that model, **Then** the model is automatically downloaded before transcription begins

### Edge Cases

- What happens when the user presses the hotkey but doesn't speak (no audio detected)?
  - System detects silence, shows brief notification "No speech detected", does not attempt transcription

- What happens when microphone permission is denied?
  - App shows permission request screen with clear instructions, prevents recording until granted

- What happens when transcription fails due to corrupted audio or model error?
  - System displays error notification, logs detailed error, pastes raw audio timestamp as fallback indicator

- What happens when the user is not focused on any text field when transcription completes?
  - System copies text to clipboard and shows notification "Text copied to clipboard (no text field detected)"

- What happens when external LLM API call fails or times out?
  - System falls back to local-only enhancement, shows notification "Using local enhancement (cloud unavailable)"

- What happens when the user records speech longer than 2 hours?
  - System warns at 2-hour mark, continues recording, may require large model for processing

- What happens when available disk space is insufficient for model download?
  - System shows clear error with space required vs. available, prevents download attempt

- What happens when the user changes clipboard content before the learning system can detect their edits?
  - Learning system misses that edit cycle, waits for next transcription-edit pairing

## Requirements

### Functional Requirements

- **FR-001**: System MUST capture audio from the configured microphone device while the designated hotkey is pressed and held
- **FR-002**: System MUST stop audio recording immediately when the hotkey is released
- **FR-003**: System MUST transcribe recorded audio locally using Whisper models without requiring internet connectivity
- **FR-004**: System MUST support selection of Whisper model sizes: tiny (75 MB), base (142 MB), small (466 MB), medium (1.5 GB), and large (2.9 GB)
- **FR-005**: System MUST automatically download selected Whisper model if not already present on first use
- **FR-006**: System MUST detect the active application to determine document type context (email, message, document, search query)
- **FR-007**: System MUST apply document-type-specific text enhancements including punctuation, capitalization, paragraph structure, and tone adjustment
- **FR-008**: System MUST remove common filler words (um, uh, like, you know) from all transcriptions
- **FR-009**: System MUST paste enhanced transcribed text into the active text field automatically after processing
- **FR-010**: System MUST display real-time visual feedback during recording (waveform, timer, status overlay)
- **FR-011**: System MUST display processing status during transcription and enhancement phases
- **FR-012**: System MUST allow users to configure the recording hotkey from available options
- **FR-013**: System MUST provide menu bar status indicator showing current application state (ready, recording, processing, pasting, error)
- **FR-014**: System MUST play audio cues for recording start, stop, completion, and error events
- **FR-015**: System MUST store Whisper models in user's Application Support directory (`~/Library/Application Support/BetterVoice/models/`)
- **FR-016**: System MUST delete temporary audio files immediately after transcription completes
- **FR-017**: System MUST monitor clipboard content after pasting to detect user edits for learning purposes
- **FR-018**: System MUST store learned formatting patterns locally in SQLite database
- **FR-019**: System MUST adapt future transcription formatting based on learned user preferences per document type
- **FR-020**: System MUST allow users to optionally enable external LLM enhancement via Claude or OpenAI APIs
- **FR-021**: System MUST store API keys securely in macOS Keychain when external LLM is enabled
- **FR-022**: System MUST send only transcribed text (never audio) to external APIs when cloud enhancement is enabled
- **FR-023**: System MUST allow users to customize system prompts for external LLM per document type
- **FR-024**: System MUST request and verify microphone, accessibility, and screen recording permissions on first launch
- **FR-025**: System MUST maintain responsive UI (<16ms frame time) during all transcription operations
- **FR-026**: System MUST complete transcription within 3 seconds for 30-second recordings using base model
- **FR-027**: System MUST limit maximum CPU usage to 50% sustained during transcription
- **FR-028**: System MUST limit memory usage to 200MB for typical sessions (500MB maximum)
- **FR-029**: System MUST support audio recordings up to 2 hours in length without crashing
- **FR-030**: System MUST provide detailed logging with configurable log levels (debug, info, warning, error)
- **FR-031**: System MUST allow users to view, clear, and export application logs
- **FR-032**: System MUST allow users to reset learned formatting patterns
- **FR-033**: System MUST allow users to export and import learning database for backup purposes
- **FR-034**: System MUST auto-detect speech language using Whisper's built-in detection
- **FR-035**: System MUST gracefully handle transcription failures with clear error messages and fallback behaviors
- **FR-036**: System MUST show estimated processing time during transcription
- **FR-037**: System MUST provide test connection functionality for external LLM APIs

### Performance Requirements

- **PR-001**: Hotkey response time MUST be under 100ms from press to recording start
- **PR-002**: Transcription latency MUST be under 3 seconds for 30-second recordings with base model
- **PR-003**: Paste operation MUST complete within 500ms of transcription completion
- **PR-004**: App launch MUST complete within 2 seconds
- **PR-005**: UI interactions MUST respond within 100ms
- **PR-006**: Real-time transcription latency MUST be under 2 seconds for local processing
- **PR-007**: Audio file transcription MUST process at minimum 1x speed (5-minute file in <5 minutes)
- **PR-008**: System MUST maintain <16ms frame time for 60fps UI during transcription

### Quality Requirements

- **QR-001**: Local transcription accuracy MUST achieve >90% word accuracy for clear speech (dependent on Whisper model baseline)
- **QR-002**: Document type detection MUST achieve >85% accuracy
- **QR-003**: Application crash rate MUST be <0.1%
- **QR-004**: Learning system MUST demonstrate measurable reduction in user edit frequency over time
- **QR-005**: Cloud-enhanced transcription MUST show measurable improvement over local-only processing

### Security Requirements

- **SR-001**: All audio data MUST remain on local device by default
- **SR-002**: Audio files MUST be deleted immediately after transcription completes
- **SR-003**: API keys MUST be stored in macOS Keychain, never in plain text
- **SR-004**: No audio data MUST be transmitted to external services unless external LLM is explicitly enabled
- **SR-005**: Only transcribed text MUST be sent to external APIs, never raw audio
- **SR-006**: User MUST explicitly opt-in to external LLM features
- **SR-007**: Logging MUST NOT record sensitive data (API keys, audio content, clipboard contents)
- **SR-008**: All network requests to cloud APIs MUST use HTTPS with certificate validation
- **SR-009**: Temporary audio files MUST be stored in sandboxed app container
- **SR-010**: Learning database MUST be stored locally with no external transmission

### Usability Requirements

- **UR-001**: Initial setup including permissions MUST be completable within 5 minutes
- **UR-002**: Users MUST achieve basic proficiency within 30 minutes of first use
- **UR-003**: Error messages MUST be actionable and non-technical when possible
- **UR-004**: All processing states MUST be clearly visible to users through menu bar and overlay feedback
- **UR-005**: Settings window MUST provide clear organization with logical tab grouping
- **UR-006**: Permission requests MUST include clear justifications for each permission type

### Key Entities

- **AudioRecording**: Represents a captured audio session including duration, timestamp, source device, audio format, and file path (temporary storage)

- **TranscriptionJob**: Represents the processing of an audio recording including selected Whisper model, detected language, processing status, start/end times, raw transcription output

- **EnhancedText**: Represents the final formatted text including detected document type, applied enhancement rules, formatting adjustments made, confidence scores, timestamp

- **DocumentTypeContext**: Represents the detected application and document type including application bundle ID, detected type (email/message/document/search), confidence score, fallback detection method used

- **LearningPattern**: Represents a learned formatting preference including document type, original transcription, user's edited version, frequency of pattern, last occurrence timestamp

- **WhisperModel**: Represents an available or installed Whisper model including model size name, file size, download status, storage path, last used timestamp

- **UserPreferences**: Represents user configuration including hotkey assignment, selected default model, audio input device, enabled enhancement types, external LLM settings, logging preferences

- **ExternalLLMConfig**: Represents cloud API configuration including provider (Claude/OpenAI), API key reference (Keychain), enabled status, custom system prompts per document type, connection test results

---

## Review & Acceptance Checklist

### Content Quality
- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

### Requirement Completeness
- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

---

## Execution Status

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked (none remaining)
- [x] User scenarios defined
- [x] Requirements generated
- [x] Entities identified
- [x] Review checklist passed

---
