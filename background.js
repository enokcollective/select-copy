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
