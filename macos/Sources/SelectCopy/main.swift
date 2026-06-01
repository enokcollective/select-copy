import AppKit

// Entry point. One binary, three modes:
//  1. Host mode  — launched by a browser for the native-messaging handshake.
//     The browser passes the calling extension's origin as argv[1]
//     ("chrome-extension://…"), which is how we detect it.
//  2. Installer  — `--install-hosts` writes the per-browser host manifests.
//  3. App mode   — the menu-bar app (default).

let args = CommandLine.arguments

if args.dropFirst().contains(where: { $0.hasPrefix("chrome-extension://") }) {
    NativeMessagingHost.run() // never returns
}

if args.contains("--install-hosts") {
    print(HostInstaller.installAll())
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu-bar only, no Dock icon

let delegate = AppDelegate()
app.delegate = delegate
app.run()
