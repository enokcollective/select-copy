# Select Copy — macOS app

A native, system-wide version of the Select Copy extension: it copies highlighted
text to the clipboard the moment you finish selecting it, in (almost) any app, and
shows a bottom-right "Copied N characters" bubble. Menu-bar only (no Dock icon).

A browser is left alone **only while its Select Copy extension is connected** (the
native-messaging handshake) — so no double-copying where the extension already
runs, while browsers without the extension still get native copy-on-select.

## How it works

- `SelectionWatcher` — global `mouseUp` / shift-`keyUp` monitor (150 ms debounce),
  the native analog of the extension's `content.js`.
- `AXReader` — reads `kAXSelectedTextAttribute` from the focused element via the
  Accessibility API. Falls back to synthesizing ⌘C and reading the pasteboard for
  apps that don't expose the attribute.
- `Pasteboard` — writes to `NSPasteboard.general`, dedupes consecutive repeats.
- `BubbleController` — borderless corner status bubble; `HotKey` registers ⌘⇧Y;
  `Settings` persists state.

### Extension handshake

- The extension's `background.js` opens a native-messaging port to the app
  (`connectNative("co.enok.selectcopy")`) and reconnects if it drops.
- The browser launches the app in **host mode** (`main.swift` detects the
  `chrome-extension://…` origin in argv). `NativeMessagingHost` resolves which
  browser launched it (`BrowserResolver` walks the parent process chain), then
  connects to the app's Unix socket and announces that browser's bundle id.
- `IPCServer` (in the running app) tracks one covered browser per live
  connection; `CoverageRegistry` reports a browser as covered while ≥1 port is
  open. `SelectionWatcher` skips the frontmost app when it's covered.
- The extension id is pinned by the `key` in `../manifest.json`, so the unpacked
  dev id and the Web Store id both match the host manifest's `allowed_origins`.
  The private signing key is **gitignored** (`extension-signing-key.pem`).

Requires **Accessibility** permission (Privacy & Security → Accessibility).

## Build & run

```sh
cd macos
./build.sh                 # → build/SelectCopy.app (ad-hoc signed)
open build/SelectCopy.app
```

On first launch, grant Accessibility access when prompted. The onboarding window
closes itself once access is granted.

Toggle on/off with **⌘⇧Y** or the menu-bar item.

### Code signing

`build.sh` auto-detects your **Developer ID Application** certificate from the
local keychain and signs with the hardened runtime. Because TCC keys on the
signing authority (not the binary hash), the Accessibility grant **persists across
rebuilds** — no re-granting. Override the identity with `SIGN_IDENTITY="…"
./build.sh`; with no matching cert it falls back to ad-hoc (grant won't persist).

One-time migration from the earlier ad-hoc builds: remove the stale **Select
Copy** entry under Privacy & Security → Accessibility, then grant the
Developer-ID-signed build once.

### Distributing to other people (notarization)

Local builds run fine unsigned-by-Apple because they aren't quarantined. To ship
the `.app` to others without Gatekeeper warnings, notarize it:

```sh
ditto -c -k --keepParent build/SelectCopy.app build/SelectCopy.zip
xcrun notarytool submit build/SelectCopy.zip --keychain-profile "<profile>" --wait
xcrun stapler staple build/SelectCopy.app
```

(`notarytool store-credentials <profile>` once, using an App Store Connect API key
or app-specific password for your Developer ID team.) No App Sandbox — this app
reads other apps' selections via Accessibility, which the sandbox would block; it's
a Developer-ID-outside-the-App-Store app, like PopClip.

### Wire up the extension handshake

1. Build + install the app (above), then run the installer so each browser knows
   how to launch the host:
   ```sh
   /Applications/SelectCopy.app/Contents/MacOS/SelectCopy --install-hosts
   ```
   (Or use the menu-bar item **Reinstall Browser Hosts** — it points the manifest
   at wherever the app currently runs from.)
2. Load the extension (the repo root) at `chrome://extensions` with Developer
   mode on. Its id should be `picanafalbiofedcmhkmacnpkogjjgdh` (pinned by `key`).
3. Verify in `~/Library/Application Support/co.enok.selectcopy/host.log` that a
   line like `resolved browser com.google.Chrome via chain […]` appears. If it
   resolves to something other than the browser, send me the chain.

## Verification checklist

Core copy-on-select — drag-select text in each and confirm the clipboard updates
+ the bubble shows the right count:

- [ ] Notes
- [ ] Mail
- [ ] Safari (page text)
- [ ] Slack or VS Code (Electron)
- [ ] Terminal
- [ ] A plain native text field (Finder rename, Spotlight)
- [ ] Preview / a PDF
- [ ] ⌘⇧Y toggles off/on (bubble shows "Select Copy off/on")
- [ ] Re-selecting the same text does not re-fire (dedupe)
- [ ] Plain clicks / typing capitals do **not** trigger a copy

Extension handshake:

- [ ] With the extension loaded in Chrome, selecting page text copies **once**
      (the extension), not twice — the app stays out.
- [ ] In a Chromium browser **without** the extension, selecting still copies (app).
- [ ] Quitting Chrome restores app coverage there within a few seconds.

Note any app where the clipboard does **not** update — that tells us whether the
⌘C fallback is carrying it or AX is failing there.
