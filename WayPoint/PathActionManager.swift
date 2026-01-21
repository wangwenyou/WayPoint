import AppKit

class PathActionManager {
    static let shared = PathActionManager()
    
    var lastActiveApp: NSRunningApplication?
    
    func openInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
    
    func copyPath(path: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
    }
    
    func openInTerminal(path: String) {
        let bundleId = StorageManager.shared.preferredTerminal
        print("💻 Attempting to open Terminal: \(bundleId) for path: \(path)")
        
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-b", bundleId, path]
        
        do {
            try task.run()
        } catch {
            print("❌ Failed to open terminal \(bundleId): \(error)")
            // 最终保命后备：系统默认终端
            let fallback = Process()
            fallback.launchPath = "/usr/bin/open"
            fallback.arguments = ["-a", "Terminal", path]
            try? fallback.run()
        }
    }
    
    func injectToDialog(path: String) {
        if !AXIsProcessTrusted() {
            showAccessibilityAlert()
            return
        }

        copyPath(path: path)
        
        if let app = lastActiveApp {
            print("🔄 Switching back to: \(app.localizedName ?? "Unknown")")
            app.activate(options: .activateIgnoringOtherApps)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🚀 Executing Injection for path: \(path)")
            self.simulateKeyPress(keyCode: 5, flags: [.maskCommand, .maskShift]) // Cmd+Shift+G
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.simulateKeyPress(keyCode: 9, flags: [.maskCommand]) // Cmd+V
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
    
    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Permission Required", comment: "")
        alert.informativeText = NSLocalizedString("WayPoint needs Accessibility permissions to inject paths. Please enable it in System Settings.", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Open Settings", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func openInEditor(path: String) {
        let bundleId = StorageManager.shared.preferredEditor
        print("📝 Attempting to open Editor: \(bundleId) for path: \(path)")
        
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-b", bundleId, path]
        
        do {
            try task.run()
        } catch {
            print("❌ Failed to open editor \(bundleId): \(error)")
            // 最终后备：系统关联的应用
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }
    
    func runCommandInTerminal(command: String, path: String) {
        let terminalId = StorageManager.shared.preferredTerminal
        
        // 生成临时脚本
        let scriptContent = """
        #!/bin/bash
        cd "\(path)"
        echo "🚀 WayPoint: Running \(command)..."
        \(command)
        # 保持窗口开启
        $SHELL
        """
        
        let tempDir = FileManager.default.temporaryDirectory
        let scriptName = "WayPoint_Action_\(Int(Date().timeIntervalSince1970)).command"
        let scriptURL = tempDir.appendingPathComponent(scriptName)
        
        do {
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            
            // 使用偏好终端打开脚本
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalId) {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.open([scriptURL], withApplicationAt: appURL, configuration: config)
            } else {
                // 回退到默认
                NSWorkspace.shared.open(scriptURL)
            }
        } catch {
            print("Failed to run command: \(error)")
        }
    }
}