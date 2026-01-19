import AppKit
import ApplicationServices
import Combine

class FinderObserver {
    static let shared = FinderObserver()
    private var lastPath: String?
    private var observer: AXObserver?
    private var targetAppElement: AXUIElement?
    private var cancellables = Set<AnyCancellable>()
    
    // 监听的事件类型
    private let notifications: [CFString] = [
        kAXFocusedWindowChangedNotification as CFString,
        kAXTitleChangedNotification as CFString, // 启用标题变化监听
        kAXWindowCreatedNotification as CFString,
        kAXMainWindowChangedNotification as CFString
    ]
    
    private var isCheckingPermissions = false
    
    private let kHasRequestedAccessibility = "HasRequestedAccessibility"

    func start() {
        // 1. 检查辅助功能权限
        // 逻辑：只在首次启动时尝试弹窗提示，后续启动不再主动打扰，除非用户使用 Inject 功能
        let hasRequested = UserDefaults.standard.bool(forKey: kHasRequestedAccessibility)
        let promptOption = !hasRequested
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptOption] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        if !hasRequested {
            UserDefaults.standard.set(true, forKey: kHasRequestedAccessibility)
        }
        
        if !isTrusted {
            print("⚠️ 未获得辅助功能权限 (Prompt: \(promptOption))")
        }
        
        // ... (后续逻辑保持不变)
        
        // ... (后续逻辑保持不变)

        
        // 2. 监听应用切换，以便在 Finder 启动或被激活时重新挂载 Observer
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] notification in
                self?.handleAppActivation(notification)
            }
            .store(in: &cancellables)
            
        // 3. 初始尝试挂载（如果 Finder 已经在运行）
        if let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
            setupObserver(for: finderApp)
        }
    }
    
    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        
        if app.bundleIdentifier == "com.apple.finder" {
            // Finder 被激活，立即抓取一次
            captureCurrentFinderPath()
            // 确保 Observer 已挂载
            setupObserver(for: app)
        }
    }
    
    private func setupObserver(for app: NSRunningApplication) {
        // 防止重复挂载
        if observer != nil { return }
        
        let pid = app.processIdentifier
        var newObserver: AXObserver?
        
        // 创建 Observer
        let result = AXObserverCreate(pid, { (observer, element, notification, refcon) in
            // 这就是 C 回调函数
            // 我们需要把 refcon 转回 Swift 对象
            if let refcon = refcon {
                let myself = Unmanaged<FinderObserver>.fromOpaque(refcon).takeUnretainedValue()
                myself.onFinderEvent(notification: notification)
            }
        }, &newObserver)
        
        guard result == .success, let axObserver = newObserver else {
            print("❌ 创建 AXObserver 失败: \(result.rawValue)")
            return
        }
        
        self.observer = axObserver
        
        // 获取 Finder 的主 UIElement
        let appElement = AXUIElementCreateApplication(pid)
        self.targetAppElement = appElement
        
        // 注册通知
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        for notif in notifications {
            let addResult = AXObserverAddNotification(axObserver, appElement, notif, selfPtr)
            if addResult != .success {
                print("⚠️ 无法注册通知 \(notif): \(addResult.rawValue)")
            }
        }
        
        // 将 Observer 添加到 RunLoop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(axObserver), .defaultMode)
        print("✅ Finder AXObserver 已启动")
    }
    
    private func onFinderEvent(notification: CFString) {
        print("🔔 Finder 事件: \(notification)") // 调试用
        
        // 事件触发时，执行 AppleScript 获取路径
        // 添加一点点延时，等待 Finder 内部状态更新完毕
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.captureCurrentFinderPath()
        }
    }
    
    private func captureCurrentFinderPath(retryCount: Int = 0) {
        // 1. 尝试通过 Accessibility API 直接获取路径 (不需要 Automation 权限)
        if let appElement = self.targetAppElement {
            var focusedWindow: AnyObject?
            // 获取当前聚焦的窗口
            let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
            
            if result == .success, let window = focusedWindow {
                let windowElement = window as! AXUIElement
                
                // 尝试获取窗口的 Document URL (kAXDocument)
                var documentUrl: AnyObject?
                var urlResult = AXUIElementCopyAttributeValue(windowElement, kAXDocumentAttribute as CFString, &documentUrl)
                
                // 如果 kAXDocument 失败，尝试 kAXURL
                if urlResult != .success {
                     // print("⚠️ kAXDocument 失败: \(urlResult.rawValue), 尝试 kAXURL") // 调试用
                     urlResult = AXUIElementCopyAttributeValue(windowElement, "AXURL" as CFString, &documentUrl)
                }

                if urlResult == .success {
                    var path: String?
                    
                    // kAXDocument 返回的是 URL (CFURL)
                    if let url = documentUrl as? URL {
                        path = url.path
                    } 
                    // 有时候可能是 String (file://...)
                    else if let urlString = documentUrl as? String, let url = URL(string: urlString) {
                        path = url.path
                    }
                    
                    if let realPath = path, !realPath.isEmpty, realPath != "/" {
                        updatePath(realPath)
                        return // 成功
                    }
                }
            }
        }
        
        // 失败重试逻辑 (最多重试 2 次)
        if retryCount < 2 {
            // 失败后稍作延迟重试
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.captureCurrentFinderPath(retryCount: retryCount + 1)
            }
            return
        }
        
        // 2. 回退到 osascript 命令行 (绕过 NSAppleScript 的部分权限限制)
        let scriptSource = """
        tell application "Finder"
            if exists Finder window 1 then
                try
                    return POSIX path of (target of Finder window 1 as alias)
                on error
                    return ""
                end try
            else
                return ""
            end if
        end tell
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", scriptSource]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty, output != "/" {
                updatePath(output)
            }
        } catch {
            print("❌ osascript execution failed: \(error)")
        }
    }
    
    private func updatePath(_ path: String) {
        // 只有路径真正变化时才更新
        if path != lastPath {
            print("📂 Finder 路径变更: \(path)")
            StorageManager.shared.addOrUpdate(path: path, source: .finderHistory)
            lastPath = path
        } else {
            print("ℹ️ 路径未变化: \(path)") // 调试用
        }
    }
    
    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "WayPoint 需要辅助功能权限"
        alert.informativeText = "为了实现“自动监听 Finder 当前路径”功能，WayPoint 需要辅助功能权限。\n\n请点击“去设置”，在“隐私与安全性 -> 辅助功能”列表中勾选 WayPoint。\n\n授权后建议重启应用以确保生效。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "去设置")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 跳转到系统设置 - 辅助功能
            // macOS 13+ 和更早版本的 URL 可能略有不同，但这个 Scheme 通常能跳转到设置主页或安全页
            let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    deinit {
        if let observer = observer {
            let runLoopSource = AXObserverGetRunLoopSource(observer)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        }
    }
}
