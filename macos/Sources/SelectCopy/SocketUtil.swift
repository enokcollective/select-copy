import Darwin

// Builds a sockaddr_un for a Unix-domain socket path and hands a sockaddr pointer
// to `body` for bind()/connect(). Shared by the app (server) and host (client).
func withUnixSocketAddress<T>(_ path: String, _ body: (UnsafePointer<sockaddr>, socklen_t) -> T) -> T {
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let capacity = MemoryLayout.size(ofValue: addr.sun_path) // read before the mutable borrow
    _ = withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
        path.withCString { cstr in
            strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cstr, capacity - 1)
        }
    }
    let len = socklen_t(MemoryLayout<sockaddr_un>.size)
    return withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { body($0, len) }
    }
}
