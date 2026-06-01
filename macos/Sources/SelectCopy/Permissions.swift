import AppKit
import ApplicationServices

// Accessibility permission gate. The CGEvent monitor and the AX selection reads
// both require the app to be a trusted Accessibility client.
enum Permissions {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    // Triggers the system prompt to add the app to Accessibility.
    @discardableResult
    static func promptForTrust() -> Bool {
        // The literal value of kAXTrustedCheckOptionPrompt; referenced directly to
        // avoid touching the non-concurrency-safe C global.
        let key = "AXTrustedCheckOptionPrompt"
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
