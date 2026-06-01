#!/usr/bin/env bash
# Build SelectCopy.app: compile the SPM executable, assemble a .app bundle with
# Info.plist, and ad-hoc codesign it. Output: macos/build/SelectCopy.app
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP_NAME="SelectCopy"
BUNDLE="build/${APP_NAME}.app"

echo "==> swift build -c ${CONFIG}"
swift build -c "${CONFIG}"

BIN="$(swift build -c "${CONFIG}" --show-bin-path)/${APP_NAME}"

echo "==> assembling ${BUNDLE}"
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources"
cp "${BIN}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "${BUNDLE}/Contents/Info.plist"

# Sign with a stable Developer ID identity when available so the Accessibility
# (TCC) grant persists across rebuilds (TCC keys on the signing authority, not the
# binary hash) and the app is notarizable for distribution. The identity is
# auto-detected from the local keychain — no team id is hard-coded here. Override
# with SIGN_IDENTITY="…" ./build.sh; falls back to ad-hoc with no Developer ID cert.
SIGN_IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -m1 "Developer ID Application" | sed -E 's/^[^"]*"([^"]*)".*/\1/')}"

if [ -n "${SIGN_IDENTITY}" ]; then
    echo "==> codesign (Developer ID, hardened runtime)"
    codesign --force --options runtime --timestamp \
        --sign "${SIGN_IDENTITY}" "${BUNDLE}"
else
    echo "==> codesign (ad-hoc — no Developer ID cert found; grant won't persist across rebuilds)"
    codesign --force --sign - "${BUNDLE}"
fi

echo "==> built ${BUNDLE}"
echo "    open it with:  open ${BUNDLE}"
