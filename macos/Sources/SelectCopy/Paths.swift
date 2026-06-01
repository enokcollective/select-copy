import Foundation

// Shared filesystem locations. Both the app and the host process (launched by the
// browser, same user) compute these identically so they meet at the socket.
enum Paths {
    static let bundleID = "co.enok.selectcopy"

    static var supportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(bundleID, isDirectory: true)
    }

    static var socketPath: String {
        supportDir.appendingPathComponent("coverage.sock").path
    }

    static var hostLogPath: String {
        supportDir.appendingPathComponent("host.log").path
    }

    static var coverageLogPath: String {
        supportDir.appendingPathComponent("coverage.log").path
    }

    static func ensureSupportDir() {
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
    }
}

// Append-only file logger. Used by host mode (whose stdout is the native-messaging
// channel and can't be used for logging) and by the app to record coverage
// changes. Read these to verify the handshake without a debugger.
enum FileLog {
    static func write(_ message: String, to path: String) {
        Paths.ensureSupportDir()
        let line = "[\(Int(Date().timeIntervalSince1970))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

enum HostLog {
    static func write(_ message: String) { FileLog.write(message, to: Paths.hostLogPath) }
}
