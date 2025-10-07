# Quickstart: Testing LLM Prompt Editor

**Feature**: 004-allow-editing-of
**Version**: 1.0
**Last Updated**: 2025-10-06

## Prerequisites

- BetterVoice app installed and running
- macOS 12.0+ (Apple Silicon or Intel)
- Microphone permission granted
- External LLM enabled (Claude API key configured)

## Test Scenario 1: View Default Prompts

**Objective**: Verify all document type prompts are visible in Settings.

**Steps**:
1. Launch BetterVoice
2. Open Settings (Cmd+,)
3. Click "Prompts" tab
4. Verify 7 document types listed:
   - Email
   - Message
   - Document
   - Social Media
   - Code
   - Search
   - Unknown

**Expected Result**:
- All types visible in a list
- Each shows "Status: Default"
- Email prompt preview shows first 50 chars of default prompt
- All prompts are read-only (view mode)

**Pass Criteria**: ✅ All 7 types visible with "Default" status

---

## Test Scenario 2: Edit Custom Prompt

**Objective**: Verify custom prompt can be saved and immediately applies.

**Steps**:
1. In Settings → Prompts tab
2. Select "Email" document type
3. Click "Edit" button
4. TextEditor appears with current prompt
5. Modify email prompt to:
   ```
   You are a brief email writer. Make this concise and professional:

   {{TEXT}}
   ```
6. Click "Save"
7. Verify status changes to "Custom"
8. Close Settings
9. Record an email: "Hey thanks for your email I appreciate your help"
10. Verify transcription is enhanced using custom prompt
11. Output should be concise per custom instructions

**Expected Result**:
- Save successful → status = "Custom"
- Next transcription uses new prompt
- No app restart required (FR-008)
- Enhanced text matches custom prompt style

**Pass Criteria**: ✅ Custom prompt applies immediately, output style matches custom instructions

---

## Test Scenario 3: Reset Individual Prompt

**Objective**: Verify individual prompt can be reset to default.

**Steps**:
1. In Settings → Prompts tab
2. Email type shows "Status: Custom" (from Scenario 2)
3. Click "Reset to Default" button for Email
4. Confirm dialog appears
5. Click "Reset"
6. Verify status changes to "Default"
7. Close Settings
8. Record same email: "Hey thanks for your email I appreciate your help"
9. Verify transcription uses default email prompt (longer, iterative analysis)

**Expected Result**:
- Status changes to "Default"
- Next transcription uses original prompt
- Output style matches default email prompt (detailed, professional)

**Pass Criteria**: ✅ Reset successful, default prompt restored immediately

---

## Test Scenario 4: Reset All Prompts

**Objective**: Verify all prompts can be reset at once.

**Setup**:
1. In Settings → Prompts tab
2. Edit 3 prompts (Email, Message, Document)
3. Save custom values for each
4. Verify all show "Status: Custom"

**Test Steps**:
1. Click "Reset All to Defaults" button at bottom
2. Confirm dialog: "Reset all 3 custom prompts to defaults?"
3. Click "Reset All"
4. Verify all types now show "Status: Default"

**Expected Result**:
- All custom prompts cleared
- Status = "Default" for all types
- customPrompts dictionary = {} in UserDefaults

**Pass Criteria**: ✅ All prompts reset, no custom values remain

---

## Test Scenario 5: Empty Prompt Handling

**Objective**: Verify empty prompts are treated as "use default" (FR-011).

**Steps**:
1. In Settings → Prompts tab
2. Select "Message" type
3. Click "Edit"
4. Delete all text (empty TextEditor)
5. Click "Save"
6. Verify no error shown
7. Verify status = "Default" (not "Custom")
8. Record a message: "heading to the store be back soon"
9. Verify transcription uses default message prompt

**Expected Result**:
- Empty prompt accepted without error
- Treated as reset to default
- Enhancement uses default prompt

**Pass Criteria**: ✅ Empty prompt = default behavior, no errors

---

## Test Scenario 6: Unlimited Prompt Length

**Objective**: Verify no character limit on custom prompts (FR-013).

**Steps**:
1. In Settings → Prompts tab
2. Select "Document" type
3. Click "Edit"
4. Paste a very long prompt (5000+ characters)
5. Click "Save"
6. Verify save successful (no truncation error)
7. Re-open Document prompt
8. Verify full text preserved

**Expected Result**:
- Long prompt saved successfully
- No character limit warning
- Full text preserved in storage

**Pass Criteria**: ✅ Prompts of any length accepted

---

## Test Scenario 7: Edit During Active Transcription

**Objective**: Verify warning shown when editing during enhancement (FR-014).

**Steps**:
1. Record a long text (30+ seconds)
2. While LLM enhancement is processing (spinner visible)
3. Open Settings → Prompts tab
4. Select Email type
5. Click "Edit"
6. Attempt to modify prompt
7. Verify warning message: "⚠️ Enhancement in progress. Changes will apply to the next operation."
8. Save new prompt
9. Current enhancement completes using old prompt
10. Record new text
11. New enhancement uses updated prompt

**Expected Result**:
- Warning displayed during active enhancement
- Save allowed (not blocked)
- Current operation uses old prompt
- Next operation uses new prompt

**Pass Criteria**: ✅ Warning shown, changes apply to next operation only

---

## Test Scenario 8: Error Fallback to Default

**Objective**: Verify auto-fallback when custom prompt causes LLM errors (FR-012).

**Steps**:
1. In Settings → Prompts tab
2. Select Email type
3. Edit prompt to malformed/problematic text:
   ```
   [invalid JSON] {{ broken syntax }}
   ```
4. Save
5. Record email: "thanks for reaching out"
6. Wait for enhancement
7. If LLM API error occurs, verify:
   - No error shown to user
   - Enhanced text returned (using default prompt)
   - Error logged in console

**Expected Result**:
- Custom prompt causes LLM error
- System silently falls back to default prompt
- User sees successful enhancement
- Error logged for debugging

**Pass Criteria**: ✅ Fallback automatic, no user interruption

---

## Test Scenario 9: Persistence Across Restart

**Objective**: Verify custom prompts persist after app restart (FR-004).

**Steps**:
1. Set custom prompts for Email, Message, Document
2. Verify all show "Status: Custom"
3. Quit BetterVoice (Cmd+Q)
4. Relaunch app
5. Open Settings → Prompts tab
6. Verify Email, Message, Document still show "Status: Custom"
7. Verify other types show "Status: Default"

**Expected Result**:
- Custom prompts preserved across restarts
- UserDefaults persists correctly

**Pass Criteria**: ✅ Prompts survive app restart

---

## Test Scenario 10: {{TEXT}} Placeholder Validation

**Objective**: Verify custom prompts work with {{TEXT}} placeholder.

**Steps**:
1. Edit Email prompt to:
   ```
   Improve this email:

   {{TEXT}}
   ```
2. Save
3. Record email: "thanks for your help"
4. Verify LLM receives prompt with transcription substituted for {{TEXT}}
5. Verify enhanced output returns

**Expected Result**:
- {{TEXT}} correctly replaced with transcription
- LLM enhancement successful
- Output matches custom prompt instructions

**Pass Criteria**: ✅ Placeholder substitution works correctly

---

## Manual Verification Checklist

After running all scenarios:

- [ ] All 7 document types visible
- [ ] Custom prompts save successfully
- [ ] Custom prompts apply immediately (no restart)
- [ ] Individual reset works
- [ ] Reset all works
- [ ] Empty prompts treated as default
- [ ] No character limit enforced
- [ ] Warning shown during active enhancement
- [ ] Error fallback works silently
- [ ] Prompts persist across restart
- [ ] {{TEXT}} placeholder works

---

## Debugging Tips

**If custom prompt not applying**:
1. Check UserDefaults: `defaults read com.bettervoice.BetterVoice`
2. Verify `customPrompts` dictionary contains entry
3. Check logs for "Using custom prompt for [type]"

**If LLM errors**:
1. Check API key configured
2. Verify external LLM enabled for document type
3. Check logs for API error messages

**If UI not updating**:
1. Verify PreferencesStore @Published property triggers
2. Check Binding(get/set) pattern in UI
3. Restart Settings window

---

*Quickstart testing guide complete - all acceptance scenarios covered*
