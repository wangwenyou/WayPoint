import AppKit

class PathActionManager {
    static let shared = PathActionManager()
    
    // 保存唤起 WayPoint 前的活跃应用
    var lastActiveApp: NSRunningApplication?
    
    // 1. 在 Finder 打开
    func openInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
    
    // 2. 复制路径
    func copyPath(path: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
    }
    
    // 3. 打开终端 (尝试 iTerm，没有则 Terminal)
    func openInTerminal(path: String) {
        let url = URL(fileURLWithPath: path)
        
        // 尝试打开 iTerm
        if let iterm = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") {
             NSWorkspace.shared.open([url], withApplicationAt: iterm, configuration: NSWorkspace.OpenConfiguration())
        } else {
            // 回退到系统终端
            if let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                NSWorkspace.shared.open([url], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
            }
        }
    }
    
    // 4. [高级功能] 注入到当前激活的文件对话框 (Open/Save Panel)
    // 注意：需要 Accessibility 权限，且 App 不能是沙盒模式(App Sandbox = NO)
    func injectToDialog(path: String) {
        // 0. 权限检查
        if !AXIsProcessTrusted() {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Permission Required", comment: "")
            alert.informativeText = NSLocalizedString("WayPoint needs Accessibility permissions to inject paths. Please enable it in System Settings.", comment: "")
            alert.alertStyle = .warning
            alert.addButton(withTitle: NSLocalizedString("Open Settings", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            
            DispatchQueue.main.async {
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                    if let url = URL(string: urlString) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            return
        }

        // 模拟按键流：Cmd+Shift+G -> 输入路径 -> Enter
        
        // A. 复制路径到剪贴板
        copyPath(path: path)
        
        // B. 尝试激活之前的应用
        if let app = lastActiveApp {
            print("🔄 Switching back to: \(app.localizedName ?? "Unknown")")
            app.activate(options: .activateIgnoringOtherApps)
        }
        
        // C. 延迟执行按键模拟
        // 等待应用切换动画完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("🚀 Executing Injection for path: \(path)")
            
            // 步骤 1: Cmd+Shift+G (打开“前往文件夹”表单)
            self.simulateKeyPress(keyCode: 5, flags: [.maskCommand, .maskShift]) // 'G' key
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                // 步骤 2: Cmd+V (粘贴路径)
                self.simulateKeyPress(keyCode: 9, flags: [.maskCommand]) // 'V' key
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    // 步骤 3: Enter (确认路径)
                    self.simulateKeyPress(keyCode: 36, flags: []) // Enter
                }
            }
        }
    }
    
    private func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = flags
        keyUp?.post(tap: .cghidEventTap)
    }
    
    // 5. 在编辑器中打开 (VS Code 等)
    func openInEditor(path: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/usr/local/bin/code") // 尝试直接调用 code
        
        // 实际上更稳妥的方法是用 /usr/bin/open -a "Visual Studio Code" <path>
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", "Visual Studio Code", path]
        
        do {
            try task.run()
        } catch {
            // 如果 VS Code 不存在，尝试默认编辑器
            let task2 = Process()
            task2.launchPath = "/usr/bin/open"
            task2.arguments = ["-t", path]
            try? task2.run()
        }
    }
}
