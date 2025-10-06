// BetterVoice Learning Assistant - Content Script
// Monitors contenteditable elements for text changes

console.log('[BetterVoice Content] Script loaded and ready');
console.log('[BetterVoice Content] URL:', window.location.href);
console.log('[BetterVoice Content] Document state:', document.readyState);

// Track the currently monitored element
let monitoredElement = null;
let originalText = null;
let debounceTimer = null;
let isMonitoring = false;
let mutationObserver = null;
let periodicCheckTimer = null;

// Detect paste events - this is when BetterVoice adds transcribed text
document.addEventListener('paste', (event) => {
  console.log('[BetterVoice Content] Paste detected - notifying background');
  console.log('[BetterVoice Content] Paste target:', event.target);
  console.log('[BetterVoice Content] Active element at paste:', document.activeElement);

  // Tell background to connect to native host
  chrome.runtime.sendMessage({ type: 'PASTE_DETECTED' });

  // Start monitoring this element after paste
  setTimeout(() => {
    const focusedElement = document.activeElement;
    console.log('[BetterVoice Content] Active element 100ms after paste:', focusedElement);

    if (focusedElement) {
      const pastedText = focusedElement.isContentEditable
        ? focusedElement.innerText
        : focusedElement.value;

      console.log('[BetterVoice Content] Pasted text length:', pastedText?.length);

      if (pastedText && pastedText.length > 10) {
        startMonitoring(pastedText);
      } else {
        console.warn('[BetterVoice Content] Text too short or missing:', pastedText?.length);
      }
    } else {
      console.warn('[BetterVoice Content] No focused element after paste');
    }
  }, 100); // Wait for paste to complete
});

// Listen for messages from background script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  console.log('[BetterVoice] Received message:', message.type);

  if (message.type === 'START_MONITORING') {
    startMonitoring(message.text);
    sendResponse({ success: true });
  } else if (message.type === 'STOP_MONITORING') {
    stopMonitoring();
    sendResponse({ success: true });
  }

  return true; // Keep channel open for async response
});

/**
 * Start monitoring the focused contenteditable element
 */
function startMonitoring(pastedText) {
  console.log('[BetterVoice] Starting monitoring for:', pastedText.substring(0, 50) + '...');

  // Find focused element
  const focusedElement = document.activeElement;

  if (!focusedElement) {
    console.warn('[BetterVoice] No focused element found');
    return;
  }

  // Check if it's editable
  const isEditable =
    focusedElement.isContentEditable ||
    focusedElement.tagName === 'TEXTAREA' ||
    focusedElement.tagName === 'INPUT';

  if (!isEditable) {
    console.warn('[BetterVoice] Focused element is not editable:', focusedElement.tagName);
    return;
  }

  // Set up monitoring
  monitoredElement = focusedElement;
  originalText = pastedText;
  isMonitoring = true;

  // Add input listener (for regular inputs/textareas)
  monitoredElement.addEventListener('input', handleInput);

  // Add blur listener (stop monitoring if focus lost)
  monitoredElement.addEventListener('blur', handleBlur);

  // For contenteditable elements (like Gmail), also use MutationObserver
  // This catches changes that don't trigger input events
  if (focusedElement.isContentEditable) {
    console.log('[BetterVoice] Setting up MutationObserver for contenteditable element');
    console.log('[BetterVoice] Element to observe:', monitoredElement);
    console.log('[BetterVoice] Element innerHTML length:', monitoredElement.innerHTML?.length);

    mutationObserver = new MutationObserver((mutations) => {
      console.log('[BetterVoice] 🔍 DOM mutation detected!', mutations.length, 'mutations');
      mutations.forEach((mutation, i) => {
        console.log(`[BetterVoice]   Mutation ${i}:`, mutation.type, mutation.target);
      });
      handleInput(); // Reuse the same debounce logic
    });

    mutationObserver.observe(monitoredElement, {
      characterData: true,
      characterDataOldValue: true,
      subtree: true,
      childList: true
    });

    console.log('[BetterVoice] ✅ MutationObserver is active');
  }

  // Also set up periodic checking every 500ms as fallback
  // This helps if events aren't firing
  periodicCheckTimer = setInterval(() => {
    if (!isMonitoring || !monitoredElement) {
      clearInterval(periodicCheckTimer);
      return;
    }

    // Get current text
    let currentText;
    if (monitoredElement.isContentEditable) {
      currentText = monitoredElement.innerText || monitoredElement.textContent;
    } else {
      currentText = monitoredElement.value;
    }

    // Check if changed
    if (currentText !== originalText) {
      console.log('[BetterVoice] 🔄 Periodic check detected change!');
      handleInput(); // Trigger debounce
    }
  }, 500);

  console.log('[BetterVoice] ✅ Monitoring started on', focusedElement.tagName);
  console.log('[BetterVoice] ✅ Periodic checking every 500ms');
}

/**
 * Stop monitoring
 */
function stopMonitoring() {
  if (!monitoredElement) return;

  console.log('[BetterVoice] Stopping monitoring');

  // Remove listeners
  monitoredElement.removeEventListener('input', handleInput);
  monitoredElement.removeEventListener('blur', handleBlur);

  // Disconnect mutation observer
  if (mutationObserver) {
    mutationObserver.disconnect();
    mutationObserver = null;
  }

  // Clear debounce timer
  if (debounceTimer) {
    clearTimeout(debounceTimer);
    debounceTimer = null;
  }

  // Clear periodic check timer
  if (periodicCheckTimer) {
    clearInterval(periodicCheckTimer);
    periodicCheckTimer = null;
  }

  // Reset state
  monitoredElement = null;
  originalText = null;
  isMonitoring = false;
}

/**
 * Handle input events (with debouncing)
 */
function handleInput(event) {
  if (!isMonitoring) return;

  console.log('[BetterVoice] 🔤 Input event detected - text is being edited');

  // Clear existing timer
  if (debounceTimer) {
    clearTimeout(debounceTimer);
  }

  // Set new timer (2 second debounce)
  debounceTimer = setTimeout(() => {
    console.log('[BetterVoice] ⏱️ Debounce timer expired - checking for edits');
    detectEditCompletion();
  }, 2000);
}

/**
 * Handle blur event (element lost focus)
 */
function handleBlur(event) {
  console.log('[BetterVoice] Element lost focus - will keep monitoring for 10 seconds');

  // EXTENDED: Don't stop for 10 seconds to allow user to click back and edit
  // Gmail often shifts focus after paste, then user clicks back to edit
  setTimeout(() => {
    if (!isMonitoring) return; // Already stopped

    console.log('[BetterVoice] 10 seconds elapsed - checking for edits and stopping');

    // Flush any pending edit detection
    if (debounceTimer) {
      clearTimeout(debounceTimer);
      debounceTimer = null;
    }

    detectEditCompletion();
    stopMonitoring();
  }, 10000); // 10 second window for editing
}

/**
 * Detect if editing is complete and send changes
 */
function detectEditCompletion() {
  if (!monitoredElement || !originalText) {
    console.log('[BetterVoice] ⚠️ Cannot detect edits - element or original text missing');
    return;
  }

  // Get current text
  let currentText;
  if (monitoredElement.isContentEditable) {
    currentText = monitoredElement.innerText || monitoredElement.textContent;
  } else {
    currentText = monitoredElement.value;
  }

  console.log('[BetterVoice] Comparing texts:');
  console.log('[BetterVoice]   Original length:', originalText.length);
  console.log('[BetterVoice]   Current length:', currentText.length);
  console.log('[BetterVoice]   Are equal:', currentText === originalText);

  // Check if text changed
  if (currentText === originalText) {
    console.log('[BetterVoice] No changes detected');
    return;
  }

  console.log('[BetterVoice] 📝 Edit detected!');
  console.log('[BetterVoice]   Original:', originalText.substring(0, 50) + '...');
  console.log('[BetterVoice]   Edited:', currentText.substring(0, 50) + '...');

  // Send to background script
  chrome.runtime.sendMessage({
    type: 'EDIT_DETECTED',
    original: originalText,
    edited: currentText,
    url: window.location.href
  });

  // Update original for next detection
  originalText = currentText;
}

// Notify background that content script is ready
chrome.runtime.sendMessage({ type: 'CONTENT_SCRIPT_READY' });
