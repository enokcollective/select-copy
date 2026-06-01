import AppKit

// Tracks which browsers are currently "covered" by a connected Select Copy
// extension. A browser is skipped by the watcher only while at least one of its
// extension's native-messaging ports is open (populated by IPCServer). Browsers
// without the extension are never skipped, so the app copies in them normally.
//
// Ref-counted because the same browser could, in principle, hold more than one
// port (e.g. multiple profiles); coverage ends only when the last one closes.
@MainActor
final class CoverageRegistry {
    static let shared = CoverageRegistry()

    private var counts: [String: Int] = [:]

    func isCovered(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return (counts[bundleID] ?? 0) > 0
    }

    func addCoverage(_ bundleID: String) {
        counts[bundleID, default: 0] += 1
        FileLog.write("covered \(bundleID) (ports=\(counts[bundleID] ?? 0)); now=[\(coveredList)]", to: Paths.coverageLogPath)
    }

    func removeCoverage(_ bundleID: String) {
        guard let c = counts[bundleID] else { return }
        if c <= 1 { counts[bundleID] = nil } else { counts[bundleID] = c - 1 }
        FileLog.write("uncovered \(bundleID); now=[\(coveredList)]", to: Paths.coverageLogPath)
    }

    private var coveredList: String {
        counts.keys.sorted().joined(separator: ", ")
    }
}
