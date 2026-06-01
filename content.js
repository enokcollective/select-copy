// Injected into every page. Watches for the end of a text selection and copies
// it to the clipboard when Select Copy is enabled.

let enabled = true;
let bannerEnabled = true;
let lastCopied = "";
let debounceTimer = null;

chrome.storage.local.get(["enabled", "bannerEnabled"], (res) => {
  enabled = res.enabled !== false; // default ON
  bannerEnabled = res.bannerEnabled !== false; // default ON
});

chrome.storage.onChanged.addListener((changes, area) => {
  if (area !== "local") return;
  if (changes.bannerEnabled) {
    bannerEnabled = changes.bannerEnabled.newValue !== false;
  }
  if (changes.enabled) {
    enabled = changes.enabled.newValue !== false;
    showBubble(enabled ? "Select Copy on" : "Select Copy off");
  }
});

function scheduleCopy() {
  if (!enabled) return;
  if (debounceTimer) clearTimeout(debounceTimer);
  debounceTimer = setTimeout(copySelection, 150);
}

function copySelection() {
  if (!enabled) return;

  const text = (window.getSelection()?.toString() ?? "").trim();
  if (!text || text === lastCopied) return;

  navigator.clipboard.writeText(text).then(onCopied, () => {
    // Fallback for unfocused frames / blocked async API: copy the live selection.
    if (document.execCommand("copy")) onCopied();
  });

  function onCopied() {
    lastCopied = text;
    // chrome.runtime is gone after the extension is reloaded/updated while this
    // tab stays open (orphaned content script). Copy + banner still work; just
    // skip the runtime message instead of throwing.
    try {
      chrome.runtime?.sendMessage({ type: "copied" });
    } catch (_) {
      /* extension context invalidated; refresh the tab to reconnect */
    }
    showBubble(`Copied ${text.length} character${text.length === 1 ? "" : "s"}`);
  }
}

// Chrome-style status bubble pinned to the bottom-right corner. Rendered in a
// shadow root so page CSS can't bleed into it. Follows the OS dark-mode setting.
let statusEl = null;
let statusTimer = null;
const darkMq = window.matchMedia("(prefers-color-scheme: dark)");

function applyTheme() {
  if (!statusEl) return;
  const dark = darkMq.matches;
  statusEl.style.color = dark ? "#e8eaed" : "#3c4043";
  statusEl.style.background = dark ? "#1f1f23" : "#e3e3e8";
  statusEl.style.borderColor = dark ? "#5f6368" : "#adadad";
  statusEl.style.boxShadow = dark
    ? "0 -1px 5px rgba(0,0,0,0.45)"
    : "0 -1px 5px rgba(0,0,0,0.08)";
}

function ensureStatus() {
  if (statusEl) return;
  const host = document.createElement("div");
  host.style.cssText =
    "all: initial; position: fixed; bottom: 0; right: 0; z-index: 2147483647; pointer-events: none;";
  const shadow = host.attachShadow({ mode: "open" });
  statusEl = document.createElement("div");
  statusEl.style.cssText = [
    "font: 12px/1.5 -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
    "border: 1px solid transparent",
    "border-right: none",
    "border-bottom: none",
    "border-top-left-radius: 7px",
    "padding: 3px 10px",
    "white-space: nowrap",
    "opacity: 0",
    "transition: opacity .12s ease",
  ].join(";");
  shadow.appendChild(statusEl);
  (document.body || document.documentElement).appendChild(host);
  applyTheme();
  darkMq.addEventListener("change", applyTheme);
}

function showBubble(text) {
  if (!bannerEnabled) return;
  ensureStatus();
  statusEl.textContent = text;
  statusEl.style.opacity = "1";
  if (statusTimer) clearTimeout(statusTimer);
  statusTimer = setTimeout(() => {
    statusEl.style.opacity = "0";
  }, 1400);
}

// mouseup = done selecting with the mouse; keyup = shift+arrow keyboard selection.
document.addEventListener("mouseup", scheduleCopy, true);
document.addEventListener("keyup", (e) => {
  if (e.shiftKey || e.key === "Shift") scheduleCopy();
}, true);
