import AppKit

// Bottom-right corner status bubble: "Copied N characters", "Select Copy on/off".
// Native analog of the shadow-DOM bubble in content.js. Borderless, click-through,
// shows over fullscreen apps, fades out after ~1.4s. Follows the OS appearance.
@MainActor
final class BubbleController {
    static let shared = BubbleController()

    private var window: NSPanel?
    private let label = NSTextField(labelWithString: "")
    private var hideWorkItem: DispatchWorkItem?

    private func ensureWindow() {
        guard window == nil else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 26),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // .screenSaver (1000) so the chip draws over fullscreen video players,
        // games, and presentation modes that raise their content above .statusBar.
        panel.level = .screenSaver
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.ignoresMouseEvents = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        // Material background, matching the Chrome-style chip.
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 7
        blur.layer?.masksToBounds = true

        label.font = .systemFont(ofSize: 12)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: blur.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: blur.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: blur.centerYAnchor),
        ])

        panel.contentView = blur
        window = panel
    }

    func show(_ text: String) {
        guard Settings.bubbleEnabled else { return }
        ensureWindow()
        guard let window else { return }

        label.stringValue = text
        label.sizeToFit()
        let width = label.frame.width + 16 // 8px padding each side
        let height: CGFloat = 26

        // Pin to the bottom-right of whichever screen has the mouse / key window.
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let margin: CGFloat = 16
            let origin = NSPoint(x: visible.maxX - width - margin, y: visible.minY + margin)
            window.setFrame(NSRect(x: origin.x, y: origin.y, width: width, height: height), display: true)
        }

        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            window.animator().alphaValue = 1
        }

        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }

    private func hide() {
        guard let window else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            window.animator().alphaValue = 0
        } completionHandler: {
            DispatchQueue.main.async { window.orderOut(nil) }
        }
    }
}
