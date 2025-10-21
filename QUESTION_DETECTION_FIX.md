# Question Detection Improvements

## Problem

Previously, questions at the end of multi-sentence transcriptions were not being detected and ended with periods instead of question marks.

**Example:**
```
Input: "The following transcription ended with a question but there was no question mark and it was a period. What can we do about that."

Expected: "...period. What can we do about that?"
Actual: "...period. What can we do about that."  ❌
```

## Root Cause

The `applyPunctuation` method was analyzing the **entire text** as a single sentence, looking only at the first word to determine sentence type. For multi-sentence text, it would see the first word of the first sentence and apply that classification to everything.

## Solution

### 1. Sentence-Level Analysis

Modified `applyPunctuation` to:
1. Split text into individual sentences
2. Analyze each sentence separately
3. Apply appropriate punctuation to each
4. Recombine sentences

**Before:**
```swift
func applyPunctuation(_ text: String) -> String {
    // Analyzed entire text as one sentence
    let type = analyzeSentenceType(text)
    return text + punctuation
}
```

**After:**
```swift
func applyPunctuation(_ text: String) -> String {
    let sentences = splitIntoSentences(trimmed)

    let punctuatedSentences = sentences.map { sentence in
        let type = analyzeSentenceType(sentence)  // Each sentence analyzed separately
        return sentence + punctuation
    }

    return punctuatedSentences.joined(separator: " ")
}
```

### 2. Enhanced Question Pattern Detection

Added more sophisticated question detection patterns:

#### Original Detection (Limited)
- Started with question word (what, when, where, etc.)
- Verb-subject inversion (is it, are you, etc.)

#### New Detection Patterns

**Tag Questions:**
- "isn't it", "don't you", "can't we", etc.
- Example: "It's good, isn't it?" → Correctly detected as question

**Or-Questions:**
- Questions with "or" choices
- Example: "Is it this or that?" → Correctly detected

**Indirect Questions:**
- WH-word + modal/auxiliary patterns
- Example: "What can we do about that?" → Correctly detected
- Pattern: `[what/how/why/when/where/which/who] + [can/could/should/would/will/do/is/are/etc.]`

**Examples Now Working:**
```
✅ "What can we do about that?"
✅ "How should I proceed?"
✅ "Why would you do that?"
✅ "When will it be ready?"
✅ "It's finished, isn't it?"
✅ "You'll help, won't you?"
✅ "Can you do this or that?"
```

## Implementation Details

### File Modified
`Services/NLP/SentenceAnalyzer.swift`

### Key Changes

1. **New Method: `splitIntoSentences`**
   - Uses regex to split on sentence boundaries (., !, ?)
   - Returns array of individual sentences
   - Handles edge cases (no punctuation, trailing text)

2. **Enhanced `analyzeSentenceType`**
   - Added tag question pattern matching
   - Added indirect question detection (WH-word + modal)
   - Added or-question detection
   - Better handling of question word combinations

3. **Updated `applyPunctuation`**
   - Processes sentences individually
   - Maintains proper spacing between sentences
   - Preserves original behavior for single sentences

## Testing

The fix handles all these cases correctly:

```swift
// Multi-sentence with question at end
"The transcription ended with a question. What can we do about that."
→ "The transcription ended with a question. What can we do about that?"

// Tag question
"It's ready, isn't it."
→ "It's ready, isn't it?"

// Multiple questions
"Who are you. What do you want. When will you arrive."
→ "Who are you? What do you want? When will you arrive?"

// Mixed statements and questions
"I have a question. How can I help. That sounds good."
→ "I have a question. How can I help? That sounds good."

// Indirect questions
"What should we do next. How can we improve this."
→ "What should we do next? How can we improve this?"
```

## Performance Impact

Minimal - the sentence splitting happens once per text enhancement, and the regex pattern is simple and efficient.

## Future Enhancements

Possible improvements for even better question detection:
- Rising intonation detection (if audio features available)
- Context-based question detection (using NaturalLanguage framework)
- Machine learning model for sentence type classification
- Support for rhetorical questions
- Multi-language question patterns

## Related Files

- `Services/NLP/SentenceAnalyzer.swift` - Main implementation
- `Services/Enhancement/TextEnhancementService.swift` - Calls SentenceAnalyzer in Stage 3
- `Services/Enhancement/FormatApplier.swift` - Also has sentence splitting logic for formatting
