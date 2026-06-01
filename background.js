// Service worker: owns the on/off state and drives the toolbar badge.
// Badge APIs only exist here, not in page content scripts.

const ON_BADGE = ""; // clean icon when enabled and idle
const OFF_BADGE = "OFF";
const FLASH_BADGE = "✓"; // ✓
const FLASH_MS = 800;

const COLOR_OFF = "#9e9e9e";
const COLOR_FLASH = "#2e7d32";

async function isEnabled() {
  const { enabled } = await chrome.storage.local.get("enabled");
  return enabled !== false; // default ON
}

async function renderIdleBadge() {
  const enabled = await isEnabled();
  if (enabled) {
    await chrome.action.setBadgeText({ text: ON_BADGE });
  } else {
    await chrome.action.setBadgeBackgroundColor({ color: COLOR_OFF });
    await chrome.action.setBadgeText({ text: OFF_BADGE });
  }
}

chrome.runtime.onInstalled.addListener(async (details) => {
  const { enabled } = await chrome.storage.local.get("enabled");
  if (enabled === undefined) {
    await chrome.storage.local.set({ enabled: true });
  }
  await renderIdleBadge();

  // Show the welcome/onboarding page on first install only.
  if (details.reason === "install") {
    chrome.tabs.create({ url: "onboarding.html" });
  }
});

chrome.runtime.onStartup.addListener(renderIdleBadge);

async function toggle() {
  const enabled = await isEnabled();
  await chrome.storage.local.set({ enabled: !enabled });
}

// Keep the badge in sync with the stored state no matter who changes it
// (toolbar click, keyboard shortcut, onboarding re-enable, options page).
chrome.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && changes.enabled) renderIdleBadge();
});

// Click the toolbar icon to toggle Select Copy.
chrome.action.onClicked.addListener(toggle);

// Keyboard shortcut (Cmd/Ctrl+Shift+Y) to toggle Select Copy.
chrome.commands.onCommand.addListener((command) => {
  if (command === "toggle-select-copy") toggle();
});

// Flash a checkmark when a content script reports a copy.
chrome.runtime.onMessage.addListener((message) => {
  if (message?.type === "copied") {
    flash();
  }
});

// Native-messaging handshake with the Select Copy macOS app. While this port is
// open, the app knows this browser is "covered" by the extension and skips its
// own copy-on-select here (so we don't double-copy). Holding the port open also
// keeps the MV3 service worker alive. If the native host isn't installed the
// connect fails harmless-ly; we just retry later. No-op on Windows/Linux where
// the app doesn't exist.
const NATIVE_HOST = "co.enok.selectcopy";
let nativePort = null;

function connectNativeHost() {
  try {
    nativePort = chrome.runtime.connectNative(NATIVE_HOST);
    nativePort.onDisconnect.addListener(() => {
      nativePort = null;
      // Back off and retry; the app may not be running yet.
      setTimeout(connectNativeHost, 5000);
    });
  } catch (_) {
    nativePort = null;
    setTimeout(connectNativeHost, 30000);
  }
}

connectNativeHost();
chrome.runtime.onStartup.addListener(connectNativeHost);

let flashTimer = null;
async function flash() {
  if (!(await isEnabled())) return;
  if (flashTimer) clearTimeout(flashTimer);
  await chrome.action.setBadgeBackgroundColor({ color: COLOR_FLASH });
  await chrome.action.setBadgeText({ text: FLASH_BADGE });
  flashTimer = setTimeout(() => {
    flashTimer = null;
    renderIdleBadge();
  }, FLASH_MS);
}
