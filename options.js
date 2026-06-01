// Options page: toggle the on-page copy banner. Persisted in chrome.storage so
// content scripts pick it up live via storage.onChanged.

const toggle = document.getElementById("bannerToggle");

chrome.storage.local.get("bannerEnabled", ({ bannerEnabled }) => {
  toggle.checked = bannerEnabled !== false; // default ON
});

toggle.addEventListener("change", () => {
  chrome.storage.local.set({ bannerEnabled: toggle.checked });
});
