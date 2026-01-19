import SwiftUI
import Carbon
import Combine

enum LocalAction: String, CaseIterable, Codable, Identifiable {
    case inject = "Inject"
    case terminal = "Open in Terminal"
    case editor = "Open in Editor"
    case copyPath = "Copy Path"
    case toggleFavorite = "Toggle Favorite"
    case exclude = "Exclude Path"
    
    var id: String { rawValue }
    
    var defaultKey: String {
        switch self {
        case .inject: return "↵"
        case .terminal: return "T"
        case .editor: return "E"
        case .copyPath: return "C"
        case .toggleFavorite: return "F"
        case .exclude: return "⌫"
        }
    }
    
    var defaultModifiers: NSEvent.ModifierFlags {
        switch self {
        case .inject: return .command
        case .terminal: return .command
        case .editor: return .command
        case .copyPath: return .command
        case .toggleFavorite: return .command
        case .exclude: return .command
        }
    }
    
    var defaultKeyCode: UInt16 {
        switch self {
        case .inject: return 36
        case .terminal: return 17
        case .editor: return 14 // E
        case .copyPath: return 8  // C
        case .toggleFavorite: return 3  // F
        case .exclude: return 51
        }
    }
}

struct LocalShortcut: Codable, Equatable {
    var keyChar: String
    var keyCode: UInt16
    var modifiers: UInt // NSEvent.ModifierFlags.rawValue
    
    var modifierFlags: NSEvent.ModifierFlags {
        return NSEvent.ModifierFlags(rawValue: modifiers).intersection([.command, .option, .control, .shift])
    }
    
    var displayString: String {
        var str = ""
        let flags = modifierFlags
        if flags.contains(.control) { str += "⌃ " }
        if flags.contains(.option) { str += "⌥ " }
        if flags.contains(.shift) { str += "⇧ " }
        if flags.contains(.command) { str += "⌘ " }
        
        let specialKeys: [UInt16: String] = [
            36: "↵", 51: "⌫", 49: "Space", 53: "Esc", 48: "Tab",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        
        if let special = specialKeys[keyCode] {
            return str + special
        }
        
        return str + keyChar.uppercased()
    }
}

class LocalShortcutManager: ObservableObject {
    static let shared = LocalShortcutManager()
    
    @Published var shortcuts: [LocalAction: LocalShortcut] = [:]
    
    private let kStorageKey = "LocalShortcutsConfigV4" // 升级版本
    
    private init() {
        load()
    }
    
    func shortcut(for action: LocalAction) -> LocalShortcut {
        return shortcuts[action] ?? LocalShortcut(keyChar: action.defaultKey, keyCode: action.defaultKeyCode, modifiers: action.defaultModifiers.rawValue)
    }
    
    func updateShortcut(action: LocalAction, keyChar: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        let cleanModifiers = modifiers.intersection([.command, .option, .control, .shift])
        let shortcut = LocalShortcut(keyChar: keyChar, keyCode: keyCode, modifiers: cleanModifiers.rawValue)
        
        DispatchQueue.main.async {
            self.shortcuts[action] = shortcut
            self.save()
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: kStorageKey),
           let decoded = try? JSONDecoder().decode([LocalAction: LocalShortcut].self, from: data) {
            self.shortcuts = decoded
        } else {
            resetToDefaults()
        }
    }
    
    func resetToDefaults() {
        var defaults: [LocalAction: LocalShortcut] = [:]
        for action in LocalAction.allCases {
            defaults[action] = LocalShortcut(
                keyChar: action.defaultKey,
                keyCode: action.defaultKeyCode,
                modifiers: action.defaultModifiers.rawValue
            )
        }
        DispatchQueue.main.async {
            self.shortcuts = defaults
            self.save()
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(encoded, forKey: kStorageKey)
        }
    }
    
    func match(event: NSEvent) -> LocalAction? {
        let relevantModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let keyCode = event.keyCode
        
        for action in LocalAction.allCases {
            let sc = shortcut(for: action)
            if sc.modifierFlags == relevantModifiers && sc.keyCode == keyCode {
                return action
            }
        }
        return nil
    }
}