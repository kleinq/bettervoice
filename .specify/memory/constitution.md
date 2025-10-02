<!--
SYNC IMPACT REPORT
==================
Version: 0.0.0 → 1.0.0 (INITIAL CONSTITUTION)
Ratification: 2025-09-30
Last Amended: 2025-09-30

Added Principles:
- I. Privacy-First Architecture
- II. Local-First Processing
- III. Native Platform Integration
- IV. Test-Driven Development (NON-NEGOTIABLE)
- V. Performance & Resource Efficiency
- VI. Optional Cloud Enhancement
- VII. User Control & Transparency

Added Sections:
- Security Requirements
- Performance Standards
- Governance

Templates Status:
- .specify/templates/plan-template.md: ✅ Compatible (constitution check section present)
- .specify/templates/spec-template.md: ✅ Compatible (requirements-focused)
- .specify/templates/tasks-template.md: ✅ Compatible (TDD workflow supported)
- .specify/templates/commands/*.md: ⚠ No command files found (will create on demand)

Follow-up TODOs: None - all placeholders resolved

Notes:
- First ratification of constitution for BetterVoice project
- Principles tailored for native macOS SwiftUI app with whisper.cpp
- Emphasis on privacy, local processing, and optional cloud features
-->

# BetterVoice Constitution

## Core Principles

### I. Privacy-First Architecture

All user data MUST remain on the user's device by default. The application MUST NOT transmit audio, transcriptions, or user content to external services without explicit user consent for each session or feature activation. Privacy settings MUST be accessible, clear, and granular.

**Rationale**: Voice transcription involves sensitive personal and professional content. Users must have complete confidence that their data is not leaving their device unless they explicitly choose cloud enhancement features.

### II. Local-First Processing

The application MUST perform all core transcription functionality using local whisper.cpp integration without requiring internet connectivity. Local processing MUST be fully functional before any cloud integration is implemented. The app MUST gracefully handle offline scenarios for all core features.

**Rationale**: Users need reliable transcription regardless of network availability. Local processing ensures privacy, reduces latency, eliminates API costs for basic usage, and provides a better user experience.

### III. Native Platform Integration

The application MUST use native macOS frameworks (SwiftUI, AppKit, AVFoundation) and follow Apple Human Interface Guidelines. The app MUST integrate with macOS system features (notifications, menu bar, keyboard shortcuts, permissions) using platform-standard APIs. All UI components MUST be native SwiftUI views.

**Rationale**: Native integration provides better performance, system consistency, accessibility support, and user trust. It ensures the app feels like a first-class macOS citizen rather than a cross-platform port.

### IV. Test-Driven Development (NON-NEGOTIABLE)

TDD is mandatory for all features. Tests MUST be written before implementation. The Red-Green-Refactor cycle MUST be strictly enforced: write failing test → implement minimum code to pass → refactor. All tests MUST pass before merging code.

**Rationale**: Swift/SwiftUI development benefits enormously from TDD discipline. Testing whisper.cpp integration, audio processing pipelines, and async cloud API calls requires test infrastructure from the start. TDD prevents architecture issues that are expensive to fix later in native development.

### V. Performance & Resource Efficiency

The application MUST maintain responsive UI (<16ms frame time for 60fps) during transcription. Local processing MUST NOT exceed 50% CPU usage on average. Memory usage MUST NOT exceed 200MB for typical sessions. Battery impact MUST be minimized through efficient audio processing and background task management.

**Rationale**: Voice transcription is often a background task. Excessive resource usage degrades user experience, drains battery, and creates negative perception of the app. macOS users expect efficient, well-behaved applications.

### VI. Optional Cloud Enhancement

Cloud API integration (Claude, OpenAI) MUST be implemented as optional enhancement layers. The application MUST function completely without API keys configured. Cloud features MUST clearly communicate when they are active and what data is being transmitted. Users MUST be able to enable/disable cloud features per-session or per-feature.

**Rationale**: Cloud APIs offer superior accuracy and additional capabilities (summarization, speaker identification, formatting) but come with privacy trade-offs and costs. Making them optional respects user choice and reduces barriers to adoption.

### VII. User Control & Transparency

All application behavior MUST be transparent to users through clear UI feedback. Processing status (local vs. cloud, model in use, estimated time) MUST be visible. Users MUST have control over model selection, quality settings, and data retention. Error messages MUST be actionable and non-technical when possible.

**Rationale**: Voice transcription involves waiting time and trust. Users need to understand what the app is doing, why it's taking time, and what choices they have. Transparency builds trust and reduces support burden.

## Security Requirements

**Authentication & API Keys**:
- API keys for cloud services MUST be stored in macOS Keychain
- No API keys or secrets MUST be hardcoded or stored in plain text
- Network requests to cloud APIs MUST use HTTPS with certificate validation

**Data Handling**:
- Temporary audio files MUST be stored in sandboxed app container
- Transcription history MUST be stored locally using encrypted CoreData or similar
- User MUST have option to auto-delete transcriptions after specified time
- Export functionality MUST allow users to extract their data in standard formats

**Permissions**:
- Microphone access MUST be requested with clear justification
- File system access MUST follow macOS sandbox rules
- Network access for cloud features MUST be explicitly disclosed

## Performance Standards

**Transcription Performance**:
- Real-time transcription MUST maintain <2 second latency for local processing
- Audio file transcription MUST process at minimum 1x speed (5 minute file in <5 minutes)
- Large file handling MUST support files up to 2 hours without crashes

**UI Responsiveness**:
- App launch MUST complete in <2 seconds
- UI interactions MUST respond within 100ms
- Background transcription MUST NOT block UI thread

**Resource Limits**:
- Maximum CPU usage: 50% sustained (can spike to 100% briefly)
- Maximum memory: 200MB for typical use, 500MB hard limit
- Disk usage: Transcription cache MUST be user-configurable with auto-cleanup

**Quality Standards**:
- Local transcription accuracy MUST meet whisper.cpp baseline performance
- Cloud-enhanced transcription MUST show measurable improvement over local
- App MUST handle poor audio quality gracefully with user feedback

## Governance

**Amendment Procedure**:
This constitution supersedes all other development practices and guidelines. Amendments require:
1. Documentation of proposed change with rationale
2. Impact analysis on existing features and architecture
3. Team review and approval (or user approval for solo projects)
4. Migration plan for affected code
5. Version increment following semantic versioning rules

**Versioning Policy**:
- MAJOR version: Backward-incompatible principle changes or principle removal
- MINOR version: New principle additions or significant expansions
- PATCH version: Clarifications, wording improvements, non-semantic fixes

**Compliance Review**:
All code reviews, feature plans, and architectural decisions MUST verify constitutional compliance. Violations MUST be documented and justified in the Complexity Tracking section of implementation plans. Complexity without justification MUST result in simplification before proceeding.

**Runtime Development Guidance**:
Refer to project root `CLAUDE.md` or agent-specific guidance files for day-to-day development workflows, tooling setup, and implementation patterns that align with these constitutional principles.

**Version**: 1.0.0 | **Ratified**: 2025-09-30 | **Last Amended**: 2025-09-30
