import AppKit
import ApplicationServices

// Reads the current text selection from the focused UI element via the
// Accessibility API. This is the native equivalent of the extension's
// `window.getSelection()` — but works in (most) native apps system-wide.
//
// Coverage is not total: some apps (certain Electron/custom text views,
// terminals) don't expose `kAXSelectedTextAttribute`. For those we fall back to
// synthesizing ⌘C and reading the pasteboard, mirroring content.js's
// `execCommand("copy")` fallback for inputs.
@MainActor
enum AXReader {

    // Best-effort read of the selected text in the frontmost app.
    // Returns nil when nothing is selected or the element doesn't expose it.
    static func selectedText() -> String? {
        let system = AXUIElementCreateSystemWide()

        guard let focused = copyElement(system, kAXFocusedUIElementAttribute) else {
            return nil
        }

        // Direct hit: the focused element exposes its selected text.
        if let text = copyString(focused, kAXSelectedTextAttribute),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }

        return nil
    }

    // MARK: - Cmd+C fallback

    // Synthesize ⌘C and wait for the pasteboard to change, then read it.
    // Returns the newly copied string, or nil if nothing landed in time.
    static func copyViaKeystroke(timeout: TimeInterval = 0.25) -> String? {
        let before = Pasteboard.changeCount
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return nil }

        let cmdC: CGKeyCode = 0x08 // 'c'
        let down = CGEvent(keyboardEventSource: src, virtualKey: cmdC, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: cmdC, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        // Poll briefly for the pasteboard changeCount to bump.
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if Pasteboard.changeCount != before {
                return Pasteboard.currentString()
            }
            usleep(10_000) // 10ms
        }
        return nil
    }

    // MARK: - AX helpers

    private static func copyElement(_ element: AXUIElement, _ attr: String) -> AXUIElement? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard err == .success, let value else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func copyString(_ element: AXUIElement, _ attr: String) -> String? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard err == .success, let value else { return nil }
        guard CFGetTypeID(value) == CFStringGetTypeID() else { return nil }
        return (value as! CFString) as String
    }
}
