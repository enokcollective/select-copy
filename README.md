# Select Copy

A Chrome extension that **automatically copies highlighted text to your clipboard**
the moment you finish selecting it, with no manual copy needed.

## Features

- **Copy on selection**: release the mouse (or finish a shift+arrow keyboard
  selection) and the highlighted text is on your clipboard.
- **Corner status bubble**: a Chrome-style tooltip in the bottom-right corner shows
  "Copied N characters" on every copy (and "Select Copy on/off" on toggle), on every
  site. Follows the OS dark-mode setting, and can be turned off in the options page.
- **Badge feedback**: the toolbar icon flashes a green `✓` on each copy.
- **Toggle on/off**: click the toolbar icon, or press the keyboard shortcut, to
  enable/disable. The state is remembered. When off, the icon shows `OFF`.
- **Runs everywhere**: all `http`/`https` pages.
- **Onboarding**: a two-step welcome page opens on first install, with a live "try
  it" demo and a guided practice of turning Select Copy off.

## Keyboard shortcut

- **macOS:** `Command+Shift+Y`
- **Windows/Linux:** `Ctrl+Shift+Y`

Rebind it at `chrome://extensions/shortcuts` if it conflicts with another binding.

## Install (unpacked)

1. Open `chrome://extensions`.
2. Enable **Developer mode** (top-right toggle).
3. Click **Load unpacked** and select this `select-copy` folder.
4. Pin the extension so you can see the badge feedback.

## How it works

- `content.js`: injected into every page; on `mouseup`/`keyup` it reads
  `window.getSelection()` and copies it via the async Clipboard API (falling back
  to `document.execCommand("copy")` for unfocused frames). It dedupes repeats,
  respects the enabled flag, and shows the corner status bubble.
- `background.js`: service worker that owns the enabled state
  (`chrome.storage.local`) and drives the toolbar badge. Handles the icon click and
  the keyboard command to toggle.
- `manifest.json`: Manifest V3.

No build step. The files are loaded directly by Chrome.

## Notes

- Selections **inside** `<input>`/`<textarea>` fields are copied via the
  `execCommand` fallback (the async Clipboard API sees them as empty).
