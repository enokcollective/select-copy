import AppKit

// Writes copied text to the general pasteboard and dedupes consecutive repeats,
// mirroring the extension's `lastCopied` guard in content.js.
@MainActor
enum Pasteboard {
    private static var lastCopied = ""

    static var changeCount: Int { NSPasteboard.general.changeCount }

    static func currentString() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    // Returns true if the text was new and got written.
    @discardableResult
    static func copy(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != lastCopied else { return false }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(trimmed, forType: .string)
        lastCopied = trimmed
        return true
    }

    // Used by the Cmd+C fallback path: a synthesized copy already populated the
    // pasteboard, so just record it for dedupe without rewriting.
    static func noteExternalCopy(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { lastCopied = trimmed }
    }

    static func isDuplicate(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) == lastCopied
    }
}
