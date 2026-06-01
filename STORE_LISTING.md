# Chrome Web Store listing copy

Paste these into the Web Store developer dashboard when submitting.

## Product details

**Name**
```
Select Copy
```

**Summary** (max 132 chars)
```
Automatically copies highlighted text to your clipboard the moment you finish selecting it.
```

**Category**: Workflow & Planning (or Tools)

**Language**: English

**Detailed description**
```
Select Copy copies whatever you highlight straight to your clipboard, so you
never have to press Ctrl/Cmd+C again.

Just select text with your mouse (or with Shift + arrow keys) and the moment you
finish, it's on your clipboard. A small status bubble in the corner confirms
"Copied N characters", and it follows your light/dark theme.

FEATURES
• Copy on selection, on every site
• Corner status bubble with the character count (matches dark mode)
• Toolbar badge that flashes a checkmark on each copy
• Turn it on/off with one click on the toolbar icon, or a keyboard shortcut
  (Ctrl/Cmd + Shift + Y). The state is remembered.
• Option to hide the on-page banner
• A quick two-step welcome guide on first install

PRIVACY
Select Copy collects nothing. Your selected text is copied locally and never
leaves your browser. The only thing stored is your on/off and banner preference,
saved locally on your device. No analytics, no servers, no tracking.
```

## Single purpose (required)

```
Select Copy automatically copies the user's highlighted text to the clipboard
the moment they finish selecting it.
```

## Permission justifications

**`storage`**
```
Used to remember the user's preferences: whether Select Copy is enabled and
whether the on-page "copied" banner is shown. Stored locally with
chrome.storage.local; nothing is transmitted.
```

**Host permissions (content script on `http://*/*` and `https://*/*`)**
```
A content script must run on the pages the user visits so the extension can
detect when text is selected and copy it to the clipboard. It only reads the
current text selection for the purpose of copying it; it does not collect or
transmit page content. Broad matches are required because copy-on-select must
work on any site the user uses.
```

Note: the extension does NOT request `clipboardWrite` (it uses the standard
user-gesture Clipboard API), `tabs`, `activeTab`, or any host permission beyond
the content-script match above.

## Privacy practices tab

- **Does this item collect user data?** No.
- Certify all three compliance checkboxes:
  - I do not sell or transfer user data to third parties, outside of approved use cases.
  - I do not use or transfer user data for purposes unrelated to my item's single purpose.
  - I do not use or transfer user data to determine creditworthiness or for lending purposes.
- **Privacy policy URL**:
  ```
  https://github.com/chandlerroth/select-copy/blob/main/PRIVACY.md
  ```

## Assets checklist

- [x] Store icon 128×128 (`icons/icon128.png`)
- [ ] At least one screenshot, 1280×800 or 640×400 (PNG/JPEG)
- [ ] (Optional) Small promo tile 440×280
- [x] Packaged ZIP: `bun run build` → `dist/select-copy-v<version>.zip`

## Submission steps

1. `bun run build` to produce `dist/select-copy-v1.0.0.zip`.
2. Go to the Chrome Web Store developer dashboard → New item → upload the ZIP.
3. Fill in the fields above, upload the 128 icon and screenshot(s).
4. Complete the Privacy practices tab and paste the privacy policy URL.
5. Submit for review.
