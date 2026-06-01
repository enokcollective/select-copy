// Onboarding page logic: two guided steps.
// 1. Copy-on-select + paste-to-confirm (the content script doesn't run on
//    chrome-extension:// pages, so this page replicates the behavior itself).
// 2. Practice toggling Select Copy off/on, detected live via chrome.storage.

const isMac =
  navigator.userAgentData?.platform === "macOS" ||
  /mac/i.test(navigator.platform);

if (isMac) {
  document.getElementById("pasteKey").textContent = "⌘";
  document.getElementById("toggleKey").textContent = "⌘+Shift+Y";
}

// ---- Step 1: copy & confirm ----
const step1 = document.getElementById("step1");
const toast = document.getElementById("toast");
const confirmArea = document.getElementById("confirmArea");
const confirmRow = document.getElementById("confirmRow");
const confirmInput = document.getElementById("confirm");
const confirmSuccess = document.getElementById("confirmSuccess");
const step1Actions = document.getElementById("step1Actions");
const toStep2 = document.getElementById("toStep2");
let toastTimer = null;
let lastCopied = "";
let step1Done = false;

function showToast() {
  toast.classList.add("show");
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove("show"), 1800);
}

function onCopied() {
  showToast();
  confirmArea.classList.add("show"); // reveal the paste box only after a copy
}

document.addEventListener("mouseup", () => {
  const text = (window.getSelection()?.toString() ?? "").trim();
  if (!text) return;
  lastCopied = text;
  navigator.clipboard.writeText(text).then(onCopied, () => {
    if (document.execCommand("copy")) onCopied();
  });
});

confirmInput.addEventListener("input", () => {
  const matched = lastCopied !== "" && confirmInput.value.trim() === lastCopied;
  confirmRow.classList.toggle("matched", matched);
  confirmSuccess.classList.toggle("show", matched);
  step1Actions.classList.toggle("show", matched);
  if (matched && !step1Done) {
    step1Done = true;
    step1.classList.add("done");
  }
});

toStep2.addEventListener("click", () => {
  step1.classList.remove("active");
  step2.classList.add("active");
  window.scrollTo({ top: 0, behavior: "smooth" });
});

// ---- Step 2: practice turning it off ----
const step2 = document.getElementById("step2");
const statusPill = document.getElementById("statusPill");
const practicePrompt = document.getElementById("practicePrompt");
let practiceStage = 0; // 0 = waiting for OFF, 1 = waiting for ON again, 2 = done

function renderEnabled(enabled) {
  statusPill.textContent = enabled ? "ON" : "OFF";
  statusPill.classList.toggle("off", !enabled);
}

if (globalThis.chrome?.storage?.local) {
  chrome.storage.local.get("enabled", ({ enabled }) => renderEnabled(enabled !== false));
  chrome.storage.onChanged.addListener((changes, area) => {
    if (area !== "local" || !changes.enabled) return;
    const enabled = changes.enabled.newValue !== false;
    renderEnabled(enabled);
    if (practiceStage === 2) return;
    if (practiceStage === 0 && !enabled) {
      practiceStage = 1;
      practicePrompt.textContent = "Nice, it's off. Now turn it back on the same way.";
    } else if (practiceStage === 1 && enabled) {
      practiceStage = 2;
      step2.classList.add("done");
      practicePrompt.textContent = "Perfect, you know how to toggle it. You're all set. ✓";
    }
  });

  // The practice has them toggle Select Copy off. Never let them leave the
  // onboarding with it still disabled, that would be annoying.
  const reenable = () => chrome.storage.local.set({ enabled: true });
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "hidden") reenable();
  });
  window.addEventListener("pagehide", reenable);
}
