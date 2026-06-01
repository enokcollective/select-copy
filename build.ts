#!/usr/bin/env bun
// Packages the extension into a clean ZIP for Chrome Web Store upload.
// Only ships the runtime files (no source SVG, docs, or build tooling).
import { $ } from "bun";

const manifest = await Bun.file("manifest.json").json();
const version = manifest.version as string;
const out = `dist/select-copy-v${version}.zip`;

const files = [
  "manifest.json",
  "background.js",
  "content.js",
  "onboarding.html",
  "onboarding.js",
  "options.html",
  "options.js",
  "icons/icon16.png",
  "icons/icon48.png",
  "icons/icon128.png",
];

await $`mkdir -p dist`;
await $`rm -f ${out}`;
await $`zip -q -X ${out} ${files}`;

console.log(`Built ${out}`);
await $`unzip -l ${out}`;
