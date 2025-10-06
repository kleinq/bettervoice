// BetterVoice Learning Assistant - Background Service Worker
// Manages communication between content script and native BetterVoice app

console.log('[BetterVoice Background] Service worker started');

let nativePort = null;
let isConnected = false;

// Connect to native messaging host (BetterVoice app)
// Only connects when needed (lazy connection)
function connectNative() {
  if (nativePort) {
    console.log('[BetterVoice Background] Already connected to native host');
    return Promise.resolve();
  }

  return new Promise((resolve, reject) => {
    try {
      nativePort = chrome.runtime.connectNative('com.bettervoice.learning');

      nativePort.onMessage.addListener((message) => {
        console.log('[BetterVoice Background] Message from native:', message);

        if (message.type === 'START_MONITORING') {
          // Forward to content script of active tab
          chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
            if (tabs[0]) {
              chrome.tabs.sendMessage(tabs[0].id, {
                type: 'START_MONITORING',
                text: message.text
              });
            }
          });
        } else if (message.type === 'STOP_MONITORING') {
          // Forward stop command
          chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
            if (tabs[0]) {
              chrome.tabs.sendMessage(tabs[0].id, { type: 'STOP_MONITORING' });
            }
          });
        }
      });

      nativePort.onDisconnect.addListener(() => {
        console.log('[BetterVoice Background] Disconnected from native host');
        const error = chrome.runtime.lastError;
        if (error) {
          console.log('[BetterVoice Background] Disconnect reason:', error.message);
        }
        nativePort = null;
        isConnected = false;
      });

      isConnected = true;
      console.log('[BetterVoice Background] ✅ Connected to native host');
      resolve();

    } catch (error) {
      console.error('[BetterVoice Background] Failed to connect to native host:', error);
      nativePort = null;
      isConnected = false;
      reject(error);
    }
  });
}

// Listen for messages from content script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  console.log('[BetterVoice Background] Message from content:', message.type);

  if (message.type === 'CONTENT_SCRIPT_READY') {
    // Content script loaded - just acknowledge (don't connect yet)
    sendResponse({ status: 'ready' });

  } else if (message.type === 'PASTE_DETECTED') {
    // Paste detected - connect to native host now
    console.log('[BetterVoice Background] Paste detected - connecting to native host');
    if (!nativePort) {
      connectNative().catch(err => {
        console.error('[BetterVoice Background] Failed to connect on paste:', err);
      });
    }
    sendResponse({ success: true });

  } else if (message.type === 'EDIT_DETECTED') {
    // Forward edit to native app - connect if needed
    if (!nativePort) {
      console.log('[BetterVoice Background] Connecting to native host for edit...');
      connectNative().then(() => {
        if (nativePort) {
          nativePort.postMessage({
            type: 'EDIT_DETECTED',
            original: message.original,
            edited: message.edited,
            url: message.url
          });
          console.log('[BetterVoice Background] ✅ Forwarded edit to native app');
        }
      }).catch(err => {
        console.error('[BetterVoice Background] Failed to connect for edit:', err);
      });
    } else {
      nativePort.postMessage({
        type: 'EDIT_DETECTED',
        original: message.original,
        edited: message.edited,
        url: message.url
      });
      console.log('[BetterVoice Background] ✅ Forwarded edit to native app');
    }
    sendResponse({ success: true });
  }

  return true;
});

// Extension loads without connecting - only connects when needed
console.log('[BetterVoice Background] Extension ready (lazy connection mode)');
