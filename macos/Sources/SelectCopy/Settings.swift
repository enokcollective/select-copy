import Foundation

// Persisted on/off state, mirrors the extension's chrome.storage.local flags.
// Defaults to ON, like background.js (`enabled !== false`).
@MainActor
enum Settings {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let enabled = "enabled"
        static let bubbleEnabled = "bubbleEnabled"
        static let hideMenuBarIcon = "hideMenuBarIcon"
    }

    static var enabled: Bool {
        get { defaults.object(forKey: Key.enabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    static var bubbleEnabled: Bool {
        get { defaults.object(forKey: Key.bubbleEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.bubbleEnabled) }
    }

    static var hideMenuBarIcon: Bool {
        get { defaults.object(forKey: Key.hideMenuBarIcon) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.hideMenuBarIcon) }
    }
}
