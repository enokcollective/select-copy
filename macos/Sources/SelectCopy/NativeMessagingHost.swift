import Foundation
import Darwin

// Native-messaging host mode. The browser launches this process when the
// extension calls chrome.runtime.connectNative("co.enok.selectcopy"). We resolve
// which browser it is, tell the running app to "cover" that browser over a Unix
// socket, and stay alive until either the browser closes the port (stdin EOF) or
// the app goes away (socket EOF). Exiting drops coverage on the app side and lets
// the extension's reconnect loop re-establish it.
enum NativeMessagingHost {

    static func run() -> Never {
        HostLog.write("host start pid=\(getpid()) ppid=\(getppid()) args=\(CommandLine.arguments)")

        let bundleID = BrowserResolver.resolveBrowserBundleID() ?? "unknown.browser"
        let sock = connectToApp()

        if sock >= 0 {
            let msg = "{\"bundleId\":\"\(bundleID)\"}\n"
            _ = msg.withCString { send(sock, $0, strlen($0), 0) }
            HostLog.write("announced coverage \(bundleID) on socket")
        } else {
            // App not running. Exit so the browser/extension retry later and relaunch us.
            HostLog.write("could not connect to app socket; exiting so extension retries")
            exit(0)
        }

        waitUntilClosed(stdinFD: 0, socketFD: sock)
        HostLog.write("port or socket closed; host exiting (coverage \(bundleID) ends)")
        exit(0)
    }

    // Connect to the app's Unix domain socket, retrying briefly in case the app is
    // still starting up.
    private static func connectToApp(retries: Int = 5) -> Int32 {
        let path = Paths.socketPath
        for attempt in 0...retries {
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            if fd < 0 { return -1 }

            let rc = withUnixSocketAddress(path) { ptr, len in connect(fd, ptr, len) }
            if rc == 0 { return fd }
            close(fd)
            if attempt < retries { usleep(500_000) } // 0.5s
        }
        return -1
    }

    // Block until either fd reports hangup/EOF. Drains and discards anything the
    // browser writes on stdin (we never need to respond).
    private static func waitUntilClosed(stdinFD: Int32, socketFD: Int32) {
        var fds = [
            pollfd(fd: stdinFD, events: Int16(POLLIN), revents: 0),
            pollfd(fd: socketFD, events: Int16(POLLIN), revents: 0),
        ]
        var buf = [UInt8](repeating: 0, count: 4096)

        while true {
            let rc = poll(&fds, nfds_t(fds.count), -1)
            if rc < 0 { if errno == EINTR { continue } else { return } }

            for pfd in fds {
                let hangup = (pfd.revents & Int16(POLLHUP | POLLERR | POLLNVAL)) != 0
                let readable = (pfd.revents & Int16(POLLIN)) != 0
                if readable {
                    let n = read(pfd.fd, &buf, buf.count)
                    if n <= 0 { return } // EOF
                } else if hangup {
                    return
                }
            }
        }
    }
}
