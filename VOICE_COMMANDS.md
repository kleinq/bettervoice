# Voice Command Prefix Feature

## Overview

BetterVoice now supports voice command prefixes that allow you to specify how your transcribed text should be formatted. By starting your dictation with "BV" or "Better Voice", you can give explicit instructions about the output format.

## How It Works

When you start your transcription with one of the supported prefixes followed by an instruction, BetterVoice will:
1. Detect the command prefix
2. Parse the formatting instruction
3. Extract the content to be formatted
4. Apply the appropriate formatting based on the instruction
5. Optionally extract recipient information for emails and messages

## Supported Prefixes

- `BV`
- `Better Voice`
- `BetterVoice`

All prefixes are case-insensitive and work the same way.

## Supported Instructions

### Email Instructions

**Pattern:** `BV, write an email to [recipient]...`

**Variations:**
- `BV, write an email to...`
- `BV, email...`
- `BV, compose an email to...`
- `BV, draft an email to...`

**Example:**
```
Input: "BV, write an email to Robert. Hi Robert, hope you're doing well. I'd love to catch up with you a little bit about what you're doing with Zulu Labs. Please let me know if you're going to be in Dallas this week. Best regards, David."

Output:
Hi Robert,

Hope you're doing well. I'd love to catch up with you a little bit about what you're doing with Zulu Labs. Please let me know if you're going to be in Dallas this week.

Best regards, David.
```

### Text Message Instructions

**Pattern:** `BV, send a text message to [recipient]...`

**Variations:**
- `BV, send a text message to...`
- `BV, text...`
- `BV, message...`
- `BV, send a slack message to...`
- `BV, slack...`

**Example:**
```
Input: "BetterVoice, send Margaret a text message. I hope you're ok"

Output: "Hi Margaret, I hope you're OK."
```

### Document Formatting Instructions

#### Memo Format

**Pattern:** `BV, write a memo about...`

**Variations:**
- `BV, write a memo about...`
- `BV, create a memo about...`

**Example:**
```
Input: "BV, write a memo about our Q4 planning meeting. We discussed revenue targets and team expansion plans."

Output:
MEMO
Date: [Current Date]

We discussed revenue targets and team expansion plans.
```

#### Bullet Points

**Pattern:** `BV, format as bullet points...`

**Example:**
```
Input: "BV, format as bullet points. First point is revenue growth. Second is team expansion. Third is customer satisfaction."

Output:
• First point is revenue growth
• Second is team expansion
• Third is customer satisfaction
```

#### To-Do List

**Pattern:** `BV, create a to-do list...`

**Example:**
```
Input: "BV, create a to-do list. Call the client. Review the proposal. Send follow-up email."

Output:
☐ Call the client
☐ Review the proposal
☐ Send follow-up email
```

#### Meeting Notes

**Pattern:** `BV, write meeting notes...`

**Variations:**
- `BV, write meeting notes...`
- `BV, create meeting notes...`
- `BV, write meeting minutes...`

#### Formal Letter

**Pattern:** `BV, write a formal letter to [recipient]...`

### Social Media Instructions

#### Tweet

**Pattern:** `BV, draft a tweet...`

**Variations:**
- `BV, draft a tweet...`
- `BV, write a tweet...`

**Features:**
- Automatically limits to 280 characters
- Adds proper capitalization and punctuation

#### LinkedIn Post

**Pattern:** `BV, compose a linkedin post...`

**Variations:**
- `BV, compose a linkedin post...`
- `BV, write a linkedin post...`
- `BV, update linkedin...`

### Search Query

**Pattern:** `BV, search for...`

**Features:**
- Removes stop words
- Extracts keywords
- Optimizes for search engines

## Direct Transcription (No Prefix)

If you don't use a prefix, BetterVoice will transcribe directly without special formatting:

**Example:**
```
Input: "Update today's LinkedIn message, reduce the length by 1000 characters"

Output: "Update today's LinkedIn message, reduce the length by 1000 characters"
```

## How Recipients Are Handled

For email and message instructions, BetterVoice automatically:
1. Detects the recipient name (usually the word(s) after "to")
2. Extracts it from the content
3. Uses it in the greeting (e.g., "Hi Robert," or "Hi Margaret,")

The recipient is identified by finding the text between the instruction and the first sentence-ending punctuation (period or exclamation mark).

## Implementation Details

### Architecture

The voice command feature is implemented as Stage -1 in the enhancement pipeline:

```
Stage -1: Voice Command Detection (NEW)
    ↓
Stage 0: ML Classification
    ↓
Stage 1: Normalization
    ↓
Stage 2: Filler Removal
    ↓
Stage 3: Punctuation & Capitalization
    ↓
Stage 4: Document Type Formatting (uses voice command metadata)
    ↓
Stage 5: Learning Patterns
    ↓
Stage 6: Cloud LLM Enhancement
```

### Key Components

1. **VoiceCommandParser** (`Services/Enhancement/VoiceCommandParser.swift`)
   - Detects command prefixes
   - Parses instruction patterns
   - Extracts recipients and content

2. **VoiceCommandInstruction** (`Models/VoiceCommandInstruction.swift`)
   - Data model for parsed commands
   - Stores instruction type, content, recipient, and metadata

3. **FormatApplier** (`Services/Enhancement/FormatApplier.swift`)
   - Enhanced to accept recipient and metadata
   - Implements special formatting for different instruction types

4. **TextEnhancementService** (`Services/Enhancement/TextEnhancementService.swift`)
   - Integrates voice command detection
   - Passes metadata through the pipeline

## Future Enhancements

Potential additions to the voice command system:
- Custom user-defined command patterns
- More sophisticated recipient extraction
- Template-based formatting
- Multi-language support
- Voice command aliases/shortcuts

## Troubleshooting

### Command Not Detected

- Ensure you're using one of the supported prefixes exactly: "BV", "Better Voice", or "BetterVoice"
- Make sure there's a comma after the prefix
- Check that you're using a supported instruction pattern

### Recipient Not Extracted

- Make sure the recipient name comes immediately after "to"
- End the recipient's name with a period or exclamation mark before the main content
- Example: "BV, email Sarah. [your message]" (not "BV, email Sarah [your message]")

### Unexpected Formatting

- Check which instruction pattern was matched (see logs)
- Verify you're using the exact pattern from the documentation
- Remember that normal text enhancement (filler removal, capitalization) still applies
