import Foundation
import Darwin

// Unix-domain socket server. Each connected native-messaging host announces one
// browser bundle id and holds the connection open; that browser stays "covered"
// (skipped by the watcher) until the connection closes. EOF == the extension's
// port went away == stop skipping that browser.
//
// All mutable state is confined to `queue` (a serial queue), so the class is
// safe to share across the GCD handlers despite @unchecked Sendable.
final class IPCServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "co.enok.selectcopy.ipc")
    private var listenFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?

    private var buffers: [Int32: Data] = [:]
    private var bundleForFD: [Int32: String] = [:]
    private var readSources: [Int32: DispatchSourceRead] = [:]

    func start() {
        queue.async { [weak self] in self?.setup() }
    }

    private func setup() {
        Paths.ensureSupportDir()
        let path = Paths.socketPath
        unlink(path) // clear any stale socket from a previous run

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }

        let bindRC = withUnixSocketAddress(path) { ptr, len in bind(fd, ptr, len) }
        guard bindRC == 0, listen(fd, 8) == 0 else { close(fd); return }

        setNonBlocking(fd)
        listenFD = fd

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptClients() }
        source.resume()
        acceptSource = source
    }

    private func acceptClients() {
        while true {
            let client = accept(listenFD, nil, nil)
            if client < 0 { break } // EAGAIN: no more pending
            setNonBlocking(client)
            buffers[client] = Data()

            let rs = DispatchSource.makeReadSource(fileDescriptor: client, queue: queue)
            rs.setEventHandler { [weak self] in self?.readClient(client) }
            rs.setCancelHandler { close(client) }
            readSources[client] = rs
            rs.resume()
        }
    }

    private func readClient(_ fd: Int32) {
        var chunk = [UInt8](repeating: 0, count: 1024)
        let n = read(fd, &chunk, chunk.count)
        if n > 0 {
            buffers[fd]?.append(contentsOf: chunk[0..<n])
            parseIfReady(fd)
        } else {
            // EOF or error: connection closed, drop this browser's coverage.
            disconnect(fd)
        }
    }

    private func parseIfReady(_ fd: Int32) {
        guard bundleForFD[fd] == nil, let data = buffers[fd],
              let nl = data.firstIndex(of: 0x0A) else { return }
        let line = data[..<nl]
        guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let bundleID = obj["bundleId"] as? String, !bundleID.isEmpty else { return }
        bundleForFD[fd] = bundleID
        Task { @MainActor in CoverageRegistry.shared.addCoverage(bundleID) }
    }

    private func disconnect(_ fd: Int32) {
        if let bundleID = bundleForFD[fd] {
            Task { @MainActor in CoverageRegistry.shared.removeCoverage(bundleID) }
        }
        readSources[fd]?.cancel()
        readSources[fd] = nil
        buffers[fd] = nil
        bundleForFD[fd] = nil
    }

    private func setNonBlocking(_ fd: Int32) {
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
    }
}
