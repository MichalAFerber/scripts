// chrome.runtime.onMessage.js - Chrome Extension Content Script (Form Copy/Paste)
//
// Content script that captures and restores form field values on any web page.
// Listens for messages from the popup (base.js) via chrome.runtime.onMessage.
//
// Actions:
//   "copy"  - Reads all <input>, <textarea>, and <select> values on the page
//             and saves them to chrome.storage.local (synchronous).
//   "paste" - Retrieves previously saved form data from chrome.storage.local
//             and writes values back into matching form fields (asynchronous).
//
// Note: Fields are matched by DOM index order, so paste works best on the
//       same page layout where copy was performed.

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'copy') {
    const formData = {};
    const inputs = document.querySelectorAll('input, textarea, select');
    inputs.forEach((input, index) => {
      formData[index] = input.value;
    });
    chrome.storage.local.set({ formData });
    sendResponse({ status: 'copied' });
  } else if (request.action === 'paste') {
    chrome.storage.local.get('formData', (result) => {
      const formData = result.formData || {};
      const inputs = document.querySelectorAll('input, textarea, select');
      inputs.forEach((input, index) => {
        if (formData[index] !== undefined) {
          input.value = formData[index];
        }
      });
      sendResponse({ status: 'pasted' });
    });
    return true; // keep message channel open for async sendResponse
  }
});
