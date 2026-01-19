import SwiftUI
import Carbon
import Combine

enum LocalAction: String, CaseIterable, Codable, Identifiable {
    case inject = "Inject"
    case terminal = "Open in Terminal"
    case editor = "Open in Editor"
    case toggleFavorite = "Toggle Favorite"
    case exclude = "Exclude Path"
    
    var id: String { rawValue }
    
    var defaultKey: String {
        switch self {
        case .inject: return "↵"
        case .terminal: return "t"
        case .editor: return "↵"
        case .toggleFavorite: return "d"
        case .exclude: return "⌫"
        }
    }
    
    var defaultModifiers: NSEvent.ModifierFlags {
        switch self {
        case .inject: return .command
        case .terminal: return .command
        case .editor: return .option
        case .toggleFavorite: return .command
        case .exclude: return .command
        }
    }
}

struct LocalShortcut: Codable, Equatable {
    var keyChar: String
    var keyCode: UInt16? // 存储 KeyCode 更准确
    var modifiers: UInt // 存储 NSEvent.ModifierFlags.rawValue
    
    var modifierFlags: NSEvent.ModifierFlags {
        return NSEvent.ModifierFlags(rawValue: modifiers)
    }
    
    var displayString: String {
        var str = ""
        let flags = modifierFlags
        if flags.contains(.control) { str += "⌃" }
        if flags.contains(.option) { str += "⌥" }
        if flags.contains(.shift) { str += "⇧" }
        if flags.contains(.command) { str += "⌘" }
        
        // 特殊按键显示
        if let code = keyCode {
            if code == 36 { return str + "↵" } // Enter
            if code == 51 { return str + "⌫" } // Delete
            if code == 49 { return str + "Space" }
        }
        
        return str + keyChar.uppercased()
    }
}

class LocalShortcutManager: ObservableObject {
    static let shared = LocalShortcutManager()
    
    @Published var shortcuts: [LocalAction: LocalShortcut] = [:]
    
    private let kStorageKey = "LocalShortcutsConfig"
    
    private init() {
        load()
    }
    
    func shortcut(for action: LocalAction) -> LocalShortcut {
        if let saved = shortcuts[action] {
            return saved
        }
        // 返回默认值
        // 注意：这里需要映射默认 KeyCode，这比较麻烦，所以简单处理：
        // 如果没有保存的，我们在 init 里应该已经 populate 了默认值
        // 如果真没有，就临时造一个
        return LocalShortcut(keyChar: action.defaultKey, keyCode: nil, modifiers: action.defaultModifiers.rawValue)
    }
    
    func updateShortcut(action: LocalAction, keyChar: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        let shortcut = LocalShortcut(keyChar: keyChar, keyCode: keyCode, modifiers: modifiers.rawValue)
        shortcuts[action] = shortcut
        save()
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: kStorageKey),
           let decoded = try? JSONDecoder().decode([LocalAction: LocalShortcut].self, from: data) {
            self.shortcuts = decoded
        } else {
            // 初始化默认值
            resetToDefaults()
        }
    }
    
    func resetToDefaults() {
        var defaults: [LocalAction: LocalShortcut] = [:]
        
        defaults[.inject] = LocalShortcut(keyChar: "↵", keyCode: 36, modifiers: NSEvent.ModifierFlags.command.rawValue)
        defaults[.terminal] = LocalShortcut(keyChar: "t", keyCode: 17, modifiers: NSEvent.ModifierFlags.command.rawValue)
        defaults[.editor] = LocalShortcut(keyChar: "↵", keyCode: 36, modifiers: NSEvent.ModifierFlags.option.rawValue)
        defaults[.toggleFavorite] = LocalShortcut(keyChar: "d", keyCode: 2, modifiers: NSEvent.ModifierFlags.command.rawValue)
        defaults[.exclude] = LocalShortcut(keyChar: "⌫", keyCode: 51, modifiers: NSEvent.ModifierFlags.command.rawValue)
        
        self.shortcuts = defaults
        save()
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(encoded, forKey: kStorageKey)
        }
    }
    
    // 检查给定的事件是否匹配某个 Action
    func match(event: NSEvent) -> LocalAction? {
        // 1. 过滤修饰键 (只关心 cmd, opt, ctrl, shift)
        let relevantModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let keyCode = event.keyCode
        
        for (action, shortcut) in shortcuts {
            // 匹配修饰键
            let savedModifiers = shortcut.modifierFlags.intersection([.command, .option, .control, .shift])
            if savedModifiers != relevantModifiers { continue }
            
            // 匹配 KeyCode (优先)
            if let savedCode = shortcut.keyCode {
                if savedCode == keyCode { return action }
            } 
            // 回退匹配 KeyChar (不推荐，但作为 fallback)
            else if let char = event.charactersIgnoringModifiers?.first, String(char).lowercased() == shortcut.keyChar.lowercased() {
                return action
            }
        }
        return nil
    }
}
