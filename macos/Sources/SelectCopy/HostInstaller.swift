import Foundation

// Writes the native-messaging host manifest into each installed browser's
// NativeMessagingHosts directory. The manifest tells the browser which binary to
// launch for `connectNative("co.enok.selectcopy")` and which extension may do so.
enum HostInstaller {

    // The pinned Select Copy extension id (see manifest.json "key").
    static let extensionID = "picanafalbiofedcmhkmacnpkogjjgdh"

    // Browser user-data dirs (under ~/Library/Application Support). The manifest
    // goes in <userDataDir>/NativeMessagingHosts/.
    private static let userDataDirs: [String] = [
        "Google/Chrome",
        "Google/Chrome Beta",
        "Google/Chrome Canary",
        "BraveSoftware/Brave-Browser",
        "Microsoft Edge",
        "Arc/User Data",
        "Vivaldi",
        "com.operasoftware.Opera",
    ]

    // Path to the binary the browser should launch — the app's own executable,
    // which self-dispatches into host mode when invoked with an extension origin.
    private static var hostBinaryPath: String {
        Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
    }

    @discardableResult
    static func installAll() -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let manifest = manifestJSON()
        var installed: [String] = []
        var skipped: [String] = []

        for relative in userDataDirs {
            let dataDir = appSupport.appendingPathComponent(relative, isDirectory: true)
            // Only install for browsers that are actually present.
            guard FileManager.default.fileExists(atPath: dataDir.path) else {
                skipped.append(relative)
                continue
            }
            let hostsDir = dataDir.appendingPathComponent("NativeMessagingHosts", isDirectory: true)
            try? FileManager.default.createDirectory(at: hostsDir, withIntermediateDirectories: true)
            let dest = hostsDir.appendingPathComponent("\(Paths.bundleID).json")
            do {
                try manifest.write(to: dest, atomically: true, encoding: .utf8)
                installed.append(relative)
            } catch {
                skipped.append("\(relative) (write failed)")
            }
        }

        var lines = ["Host binary: \(hostBinaryPath)"]
        if !installed.isEmpty { lines.append("Installed for: \(installed.joined(separator: ", "))") }
        if !skipped.isEmpty { lines.append("Not present / skipped: \(skipped.joined(separator: ", "))") }
        return lines.joined(separator: "\n")
    }

    private static func manifestJSON() -> String {
        """
        {
          "name": "\(Paths.bundleID)",
          "description": "Select Copy coverage handshake",
          "path": "\(hostBinaryPath)",
          "type": "stdio",
          "allowed_origins": ["chrome-extension://\(extensionID)/"]
        }
        """
    }
}
