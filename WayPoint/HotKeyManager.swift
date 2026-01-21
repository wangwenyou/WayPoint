import Carbon
import AppKit

// 定义回调
private func hotKeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData = userData else { return noErr }
    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    
    // 转发给主线程处理
    DispatchQueue.main.async {
        manager.onHotKeyTriggered?()
    }
    
    // 关键：必须调用后续处理器并返回
    if let next = nextHandler {
        return CallNextEventHandler(next, event)
    }
    return noErr
}

class HotKeyManager {
    static let shared = HotKeyManager()
    
    private let hotKeyID = EventHotKeyID(signature: 0x5750, id: 1)
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    var onHotKeyTriggered: (() -> Void)?
    
    func register() {
        if let existingRef = hotKeyRef {
            UnregisterEventHotKey(existingRef)
            hotKeyRef = nil
        }
        
        let savedCode = UserDefaults.standard.integer(forKey: "SavedHotKeyCode")
        let savedMods = UserDefaults.standard.integer(forKey: "SavedHotKeyModifiers")
        
        let keyCode = savedCode != 0 ? UInt32(savedCode) : UInt32(kVK_Space)
        let modifiers = savedCode != 0 ? UInt32(savedMods) : UInt32(optionKey)
        
        var newRef: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &newRef)
        self.hotKeyRef = newRef
        
        if eventHandler == nil { setupEventHandler() }
    }
    
    func updateHotKey(keyCode: UInt32, modifiers: UInt32) {
        UserDefaults.standard.set(Int(keyCode), forKey: "SavedHotKeyCode")
        UserDefaults.standard.set(Int(modifiers), forKey: "SavedHotKeyModifiers")
        register()
    }
    
    private func setupEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, selfPtr, &eventHandler)
    }
}