import AppKit
import Carbon.HIToolbox

// Global ⌘⇧Y hotkey to toggle Select Copy, matching the extension's command.
// Carbon's RegisterEventHotKey is the reliable way to register and *consume* a
// system-wide hotkey (NSEvent global monitors can observe but not swallow it).
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let onFire: () -> Void

    // 'Y' on the US layout; Carbon uses virtual key codes (kVK_ANSI_Y = 0x10).
    private let keyCode = UInt32(kVK_ANSI_Y)
    private let modifiers = UInt32(cmdKey | shiftKey)

    init(onFire: @escaping () -> Void) {
        self.onFire = onFire
        register()
    }

    private func register() {
        let signature: OSType = 0x53435059 // 'SCPY'
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            let me = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            me.onFire()
            return noErr
        }, 1, &spec, selfPtr, &handler)

        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
