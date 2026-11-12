import AppKit
import Carbon.HIToolbox

/// A key with its modifiers, in the form the system's hot key service takes.
struct HotKeyCombo: Equatable {
    var keyCode: UInt32
    /// Carbon modifier mask (cmdKey, shiftKey, optionKey, controlKey).
    var modifiers: UInt32
    /// How it is shown, for example "⌃⌥F".
    var label: String

    static let standard = HotKeyCombo(
        keyCode: UInt32(kVK_ANSI_F),
        modifiers: UInt32(controlKey | optionKey),
        label: "⌃⌥F"
    )

    init(keyCode: UInt32, modifiers: UInt32, label: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
    }

    /// From a key press. Nil unless Control or Command is held: a shortcut without either
    /// would get in the way of typing, and the system refuses most of them anyway.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard flags.contains(.control) || flags.contains(.command) else { return nil }
        var mask = 0
        var symbols = ""
        if flags.contains(.control) { mask |= controlKey; symbols += "⌃" }
        if flags.contains(.option) { mask |= optionKey; symbols += "⌥" }
        if flags.contains(.shift) { mask |= shiftKey; symbols += "⇧" }
        if flags.contains(.command) { mask |= cmdKey; symbols += "⌘" }
        let name = Self.keyNames[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "?"
        self.init(keyCode: UInt32(event.keyCode), modifiers: UInt32(mask), label: symbols + name)
    }

    /// Keys by their position on the keyboard, so the label does not depend on the input language.
    private static let keyNames: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B",
        12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4",
        22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
        32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
        43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 50: "`",
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]

    // MARK: - Storage

    init?(stored: [String: Any]) {
        guard let keyCode = stored["keyCode"] as? Int,
              let modifiers = stored["modifiers"] as? Int,
              let label = stored["label"] as? String else { return nil }
        self.init(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers), label: label)
    }

    var stored: [String: Any] {
        ["keyCode": Int(keyCode), "modifiers": Int(modifiers), "label": label]
    }
}

/// One system-wide hot key. It works whichever app is in front and needs no permissions.
@MainActor
final class HotKey: ObservableObject {
    static let shared = HotKey()

    var onPress: (() -> Void)?
    /// The system refused the shortcut that was last asked for, usually because something else has it.
    @Published private(set) var refused = false

    private var registration: EventHotKeyRef?
    private var handler: EventHandlerRef?

    private init() {}

    /// Makes `combo` the hot key, or switches the hot key off for nil.
    func bind(_ combo: HotKeyCombo?) {
        release()
        refused = false
        guard let combo = combo else { return }
        listen()
        let id = EventHotKeyID(signature: OSType(0x424C_494B), id: 1)  // "BLIK"
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &reference)
        if status == noErr {
            registration = reference
        } else {
            refused = true
        }
    }

    /// Lets go of the hot key, for instance while a new one is being recorded.
    func release() {
        if let registration = registration {
            UnregisterEventHotKey(registration)
        }
        registration = nil
    }

    private func listen() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            Task { @MainActor in
                HotKey.shared.onPress?()
            }
            return noErr
        }, 1, &spec, nil, &handler)
    }
}
