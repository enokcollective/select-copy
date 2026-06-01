import AppKit

// First-launch window shown until the user grants Accessibility. Explains why the
// permission is needed and offers a deep link to the settings pane. The
// AppDelegate polls AXIsProcessTrusted() and closes this once granted.
@MainActor
final class OnboardingWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Select Copy"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildContent()
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }

        let title = NSTextField(labelWithString: "Select Copy needs Accessibility access")
        title.font = .systemFont(ofSize: 17, weight: .semibold)

        let body = NSTextField(wrappingLabelWithString: """
        Select Copy copies highlighted text to your clipboard the moment you \
        finish selecting it, in any app.

        To read your selection, macOS requires Accessibility permission. Open \
        Privacy & Security → Accessibility and enable Select Copy. This window \
        closes automatically once access is granted.
        """)
        body.font = .systemFont(ofSize: 13)

        let openButton = NSButton(title: "Open Accessibility Settings", target: self, action: #selector(openSettings))
        openButton.bezelStyle = .rounded
        openButton.keyEquivalent = "\r"

        let stack = NSStackView(views: [title, body, openButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
        ])
    }

    @objc private func openSettings() {
        Permissions.openAccessibilitySettings()
    }
}
