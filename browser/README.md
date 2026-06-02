# browser/ — Chrome extension prototypes

Tiny prototype snippets for Chrome extension messaging. Kept as reference for the early form copy/paste pattern that grew into **[CopyWizard](https://copywizard.us)** — see the [`MichalAFerber/copywizard`](https://github.com/MichalAFerber/copywizard) repo for the production extension.

## Files

| File | Role |
|---|---|
| `base.js` | Popup script — dispatches `copy`/`paste` action to the active tab's content script |
| `chrome.runtime.onMessage.js` | Content script — captures `<input>`/`<textarea>`/`<select>` values to `chrome.storage.local` on `copy`, restores them on `paste` |

## Notes

- DOM-index-based matching only — works on the same page layout where copy was performed
- No persistence beyond `chrome.storage.local` (browser profile-scoped)
- Not a full extension — you'd need a `manifest.json` declaring `base.js` as the popup script and `chrome.runtime.onMessage.js` as a content script

For the production form-mapping work, use **CopyWizard** which adds field-name mapping, profiles, and per-domain auto-detect.
