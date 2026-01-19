import Carbon
import AppKit

// 1. 定义一个全局 C 函数作为回调，确保绝对兼容
private func hotKeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    // 这里的 userData 就是我们在 InstallEventHandler 传入的 self 指针
    guard let userData = userData else { return noErr }
    
    // 恢复 Swift 对象实例
    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    
    // 回到主线程处理
    DispatchQueue.main.async {
        print("🔥 全局快捷键被触发 (C Callback)!")
        manager.onHotKeyTriggered?()
    }
    
    return noErr
}

class HotKeyManager {
    static let shared = HotKeyManager()
    
    private let hotKeyID = EventHotKeyID(signature: 0x5750, id: 1)
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    var onHotKeyTriggered: (() -> Void)?
    
    private let kSavedKeyCode = "SavedHotKeyCode"
    private let kSavedModifiers = "SavedHotKeyModifiers"
    
    func register() {
//        print("⌨️ 开始注册快捷键...")
        
        // 清理旧注册
        if let existingRef = hotKeyRef {
            UnregisterEventHotKey(existingRef)
            hotKeyRef = nil
        }
        
        // 1. 尝试从 UserDefaults 读取
        let savedCode = UserDefaults.standard.integer(forKey: kSavedKeyCode)
        let savedMods = UserDefaults.standard.integer(forKey: kSavedModifiers)
        
        let keyCode: UInt32
        let modifiers: UInt32
        
        if savedCode != 0 {
            keyCode = UInt32(savedCode)
            modifiers = UInt32(savedMods)
        } else {
            // 默认: Alt + Space (Option + Space)
            keyCode = UInt32(kVK_Space) // 49
            modifiers = UInt32(optionKey)
        }
        
        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newRef
        )
        
        if status != noErr {
            print("❌ 注册失败: \(status)")
            return
        }
        
        self.hotKeyRef = newRef
//        print("✅ 注册成功: Code \(keyCode), Mods \(modifiers)")
        
        // 安装事件监听
        if eventHandler == nil {
            setupEventHandler()
        }
    }
    
    func updateHotKey(keyCode: UInt32, modifiers: UInt32) {
        UserDefaults.standard.set(Int(keyCode), forKey: kSavedKeyCode)
        UserDefaults.standard.set(Int(modifiers), forKey: kSavedModifiers)
        register()
    }
    
    private func setupEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        // 传入 self 指针
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler, // 使用全局 C 函数
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        
        if installStatus != noErr {
            print("❌ 监听器安装失败: \(installStatus)")
        } else {
            print("✅ 监听器安装成功")
        }
    }
}
