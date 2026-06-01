import AppKit
import Carbon.HIToolbox

// Watches for the end of a text selection system-wide and copies it, the native
// analog of content.js. mouseUp after a drag = done selecting with the mouse;
// shift+arrow keyUp = keyboard selection. Debounced 150ms, like scheduleCopy.
//
// Two gates keep the ⌘C fallback from misfiring on ordinary input:
//  - mouse: a *drag* (moved > threshold between down and up) or a multi-click
//    (double-click selects a word, triple-click a paragraph) counts; a plain
//    single click places a cursor and selects nothing, so it's ignored.
//  - keyboard: only shift + navigation keys (arrows / home / end / page) count,
//    so typing capital letters never triggers a copy.
@MainActor
final class SelectionWatcher {
    private var downMonitor: Any?
    private var mouseMonitor: Any?
    private var keyMonitor: Any?
    private var debounce: DispatchWorkItem?

    private var mouseDownLocation: NSPoint?
    private let dragThreshold: CGFloat = 3

    // Shift + one of these = a keyboard selection gesture.
    private let navKeys: Set<UInt16> = [
        UInt16(kVK_LeftArrow), UInt16(kVK_RightArrow),
        UInt16(kVK_UpArrow), UInt16(kVK_DownArrow),
        UInt16(kVK_Home), UInt16(kVK_End),
        UInt16(kVK_PageUp), UInt16(kVK_PageDown),
    ]

    // Called after a successful copy with the character count, so the UI can
    // flash the menu-bar icon and show the corner bubble.
    var onCopied: ((Int) -> Void)?

    func start() {
        guard mouseMonitor == nil else { return }

        downMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            self?.mouseDownLocation = NSEvent.mouseLocation
        }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            guard let self else { return }
            let up = NSEvent.mouseLocation
            let dragged = self.mouseDownLocation.map { hypot(up.x - $0.x, up.y - $0.y) > self.dragThreshold } ?? false
            self.mouseDownLocation = nil
            // clickCount >= 2 is a double/triple-click word/paragraph selection.
            if dragged || event.clickCount >= 2 { self.schedule() }
        }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyUp]) { [weak self] event in
            guard let self else { return }
            if event.modifierFlags.contains(.shift) && self.navKeys.contains(event.keyCode) {
                self.schedule()
            }
        }
    }

    func stop() {
        if let m = downMonitor { NSEvent.removeMonitor(m) }
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        if let k = keyMonitor { NSEvent.removeMonitor(k) }
        downMonitor = nil
        mouseMonitor = nil
        keyMonitor = nil
        debounce?.cancel()
    }

    private func schedule() {
        guard Settings.enabled else { return }
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.capture() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func capture() {
        guard Settings.enabled else { return }

        // Skip apps already handled by a browser extension.
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if CoverageRegistry.shared.isCovered(front) { return }

        // Primary path: Accessibility selected-text.
        if let text = AXReader.selectedText() {
            if Pasteboard.copy(text) {
                onCopied?(text.trimmingCharacters(in: .whitespacesAndNewlines).count)
            }
            return
        }

        // Fallback: synthesize ⌘C and read what lands on the pasteboard. Only
        // reached after a real drag/shift-arrow gesture where AX gave us nothing,
        // i.e. an app that doesn't expose kAXSelectedTextAttribute.
        if let copied = AXReader.copyViaKeystroke() {
            let trimmed = copied.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !Pasteboard.isDuplicate(copied) {
                Pasteboard.noteExternalCopy(copied)
                onCopied?(trimmed.count)
            }
        }
    }
}
