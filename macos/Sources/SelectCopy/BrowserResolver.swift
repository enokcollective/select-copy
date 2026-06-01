import AppKit
import Darwin

// Resolves which browser launched the native-messaging host. Chrome launches the
// host as a child process, but the immediate parent may be a helper/utility
// process, so we walk up the parent chain until we find a known browser bundle
// id. The result must match NSWorkspace.frontmostApplication.bundleIdentifier so
// the watcher's coverage check lines up.
enum BrowserResolver {

    // Bundle ids the watcher also recognises as "a browser". Kept here because
    // host mode runs as a separate, UI-less process.
    static let browserBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.canary",
        "com.google.Chrome.dev",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.brave.Browser.nightly",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.beta",
        "company.thebrowser.Browser", // Arc
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
    ]

    // Walk up from `startPID` (default: this process's parent) looking for a
    // browser. Returns its bundle id, or the first resolvable bundle id as a
    // best-effort fallback. Logs the chain for diagnostics.
    static func resolveBrowserBundleID(startPID: pid_t = getppid(), maxDepth: Int = 8) -> String? {
        var pid = startPID
        var firstResolved: String?
        var chain: [String] = []

        for _ in 0..<maxDepth {
            guard pid > 1 else { break }
            let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
            chain.append("\(pid):\(bundleID ?? "-")")
            if let bundleID {
                if firstResolved == nil { firstResolved = bundleID }
                if browserBundleIDs.contains(bundleID) {
                    HostLog.write("resolved browser \(bundleID) via chain [\(chain.joined(separator: " <- "))]")
                    return bundleID
                }
            }
            pid = parentPID(of: pid)
        }

        HostLog.write("no known browser in chain [\(chain.joined(separator: " <- "))]; falling back to \(firstResolved ?? "nil")")
        return firstResolved
    }

    // Parent pid via sysctl KERN_PROC_PID -> kinfo_proc.
    private static func parentPID(of pid: pid_t) -> pid_t {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let rc = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        guard rc == 0, size > 0 else { return 0 }
        return info.kp_eproc.e_ppid
    }
}
