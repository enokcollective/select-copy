import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let watcher = SelectionWatcher()
    private var hotKey: HotKey?
    private var onboarding: OnboardingWindowController?
    private var flashTimer: Timer?
    private var trustPoll: Timer?
    private let ipc = IPCServer()

    // Menu items we toggle checkmarks on.
    private let enableItem = NSMenuItem(title: "Enable Select Copy", action: #selector(toggleEnabled), keyEquivalent: "")
    private let bubbleItem = NSMenuItem(title: "Show Copy Banner", action: #selector(toggleBubble), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        // Self-register the native-messaging host manifest for every installed
        // browser, pointing at wherever this app currently runs from. Idempotent
        // and cheap, so doing it on each launch keeps the manifest correct after
        // the app moves or a new browser is installed. (A sandboxed extension
        // cannot do this itself, which is why the app owns it.)
        FileLog.write("install-hosts on launch:\n\(HostInstaller.installAll())", to: Paths.coverageLogPath)

        // Listen for extension handshakes so browsers running the extension are
        // skipped only while their port is connected.
        ipc.start()

        watcher.onCopied = { [weak self] count in
            self?.flashCopied()
            BubbleController.shared.show("Copied \(count) character\(count == 1 ? "" : "s")")
        }

        hotKey = HotKey { [weak self] in
            Task { @MainActor in self?.toggleEnabled() }
        }

        gateOnAccessibility()
    }

    // MARK: - Status item / menu

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        renderIcon()

        let menu = NSMenu()
        enableItem.target = self
        bubbleItem.target = self
        menu.addItem(enableItem)
        menu.addItem(.separator())
        menu.addItem(bubbleItem)
        menu.addItem(.separator())

        let axItem = NSMenuItem(title: "Open Accessibility Settings…", action: #selector(openAX), keyEquivalent: "")
        axItem.target = self
        menu.addItem(axItem)

        let quitItem = NSMenuItem(title: "Quit Select Copy", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        refreshChecks()
    }

    private func refreshChecks() {
        enableItem.state = Settings.enabled ? .on : .off
        bubbleItem.state = Settings.bubbleEnabled ? .on : .off
    }

    private func renderIcon() {
        guard let button = statusItem.button else { return }
        // Text-selection glyph (a character with an I-beam cursor). The disabled
        // state is shown by dimming the same icon (appearsDisabled). Fall back to a
        // stable older symbol if this one is ever unavailable.
        let image = NSImage(systemSymbolName: "character.cursor.ibeam", accessibilityDescription: "Select Copy")
            ?? NSImage(systemSymbolName: "text.cursor", accessibilityDescription: "Select Copy")
        image?.isTemplate = true
        button.image = image
        button.appearsDisabled = !Settings.enabled
        button.toolTip = Settings.enabled ? "Select Copy: on" : "Select Copy: off"
    }

    private func flashCopied() {
        guard let button = statusItem.button else { return }
        let config = NSImage.SymbolConfiguration(paletteColors: [.systemGreen])
        let check = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Copied")?
            .withSymbolConfiguration(config)
        check?.isTemplate = false
        button.image = check
        button.appearsDisabled = false

        flashTimer?.invalidate()
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.renderIcon() }
        }
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        Settings.enabled.toggle()
        refreshChecks()
        renderIcon()
        BubbleController.shared.show(Settings.enabled ? "Select Copy on" : "Select Copy off")
    }

    @objc private func toggleBubble() {
        Settings.bubbleEnabled.toggle()
        refreshChecks()
    }

    @objc private func openAX() {
        Permissions.openAccessibilitySettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Accessibility gating

    private func gateOnAccessibility() {
        if Permissions.isTrusted {
            watcher.start()
            return
        }

        // Show onboarding and poll until the user grants Accessibility.
        let controller = OnboardingWindowController()
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboarding = controller
        Permissions.promptForTrust()

        trustPoll = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard Permissions.isTrusted else { return }
            Task { @MainActor in self?.onAccessibilityGranted() }
        }
    }

    private func onAccessibilityGranted() {
        trustPoll?.invalidate()
        trustPoll = nil
        onboarding?.close()
        onboarding = nil
        watcher.start()
    }
}
