// base.js - Chrome Extension Popup Script (Form Copy/Paste)
//
// Popup UI handler for a Chrome extension that copies and pastes form field
// values between web pages. Works with chrome.runtime.onMessage.js (content script).
//
// How it works:
//   1. User selects "copy" or "paste" from the popup dropdown (#action element)
//   2. This script sends the chosen action to the active tab's content script
//   3. The content script (chrome.runtime.onMessage.js) handles the actual DOM work
//
// Prerequisites:
//   - manifest.json must declare this as the popup script
//   - chrome.runtime.onMessage.js must be injected as a content script

document.getElementById('action').addEventListener('change', (e) => {
  const action = e.target.value;
  if (action === 'copy') {
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      chrome.tabs.sendMessage(tabs[0].id, { action: 'copy' });
    });
  } else if (action === 'paste') {
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      chrome.tabs.sendMessage(tabs[0].id, { action: 'paste' });
    });
  }
});
