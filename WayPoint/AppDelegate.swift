import Cocoa
import SwiftUI
import Combine

extension Notification.Name {
    static let closeWayPointWindow = Notification.Name("closeWayPointWindow")
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    var panel: KeyablePanel!
    var statusBarItem: NSStatusItem!
    var finderObserver = FinderObserver.shared // 保持引用
    var clipboardWatcher = ClipboardWatcher()  // 保持引用
    private var menuCancellable: AnyCancellable?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 APP LAUNCHED! AppDelegate is running!")
        
        // 设置为附属应用，不显示 Dock 图标，但在切换时更轻量
        NSApp.setActivationPolicy(.accessory)
        
        // 1. 启动监听服务
        finderObserver.start()
        // clipboardWatcher 已经在初始化时启动
                
        // 2. 创建菜单栏图标
        setupStatusBar()
        
        // 3. 创建无边框窗口 (Spotlight 风格)
        createPanel()
        
        // 启动 Finder 监听
        FinderObserver.shared.start()
        
        // 4. 注册全局快捷键
        HotKeyManager.shared.register()
        HotKeyManager.shared.onHotKeyTriggered = { [weak self] in
            DispatchQueue.main.async {
                print("🎹 Hotkey triggered!")
                self?.togglePanel()
            }
        }
        
        // 5. 监听数据变化以更新菜单
        setupMenuSubscription()
    }
    
    private func setupMenuSubscription() {
        menuCancellable = StorageManager.shared.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.updateStatusBarMenu(items: items)
            }
    }
    
    private func updateStatusBarMenu(items: [PathItem]) {
        guard let menu = statusBarItem.menu else { return }
        
        // 1. 清理旧的动态项 (我们约定动态项插在“About”之后，“Show Search”之前)
        // 先简单点：清空所有，重新添加
        menu.removeAllItems()
        
        // 2. 添加固定项和动态项
        menu.addItem(NSMenuItem(title: NSLocalizedString("About WayPoint", comment: ""), action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        // 3. 添加 Top 5 项目
        let topItems = items.sorted { $0.score > $1.score }.prefix(5)
        if !topItems.isEmpty {
            for item in topItems {
                let menuItem = NSMenuItem(title: item.alias, action: #selector(openRecentItem(_:)), keyEquivalent: "")
                menuItem.representedObject = item.path
                menuItem.toolTip = item.path
                menu.addItem(menuItem)
            }
            menu.addItem(NSMenuItem.separator())
        }
        
        menu.addItem(NSMenuItem(title: NSLocalizedString("Show Search Window", comment: ""), action: #selector(showSearchPanel), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("Quit", comment: ""), action: #selector(quitApp), keyEquivalent: "q"))
    }
    
    @objc func openRecentItem(_ sender: NSMenuItem) {
        if let path = sender.representedObject as? String {
            PathActionManager.shared.openInFinder(path: path)
            StorageManager.shared.addOrUpdate(path: path, source: .manual)
        }
    }
    
    private func setupStatusBar() {
        // 创建状态栏图标
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusBarItem.button {
            let iconName = "location.circle.fill"
            if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "WayPoint") {
                image.isTemplate = true // 自动适配深色/浅色模式
                button.image = image
            } else {
                print("⚠️ Failed to load status bar icon: \(iconName)")
                button.title = "WP" // Fallback title
            }
        } else {
            print("❌ Failed to get status bar button")
        }
        
        statusBarItem.isVisible = true
        
        // 创建菜单
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: NSLocalizedString("About WayPoint", comment: ""), action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("Show Search Window", comment: ""), action: #selector(showSearchPanel), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("Quit", comment: ""), action: #selector(quitApp), keyEquivalent: "q"))
        
        statusBarItem.menu = menu
        print("✅ Status bar item setup complete")
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "WayPoint"
        alert.informativeText = NSLocalizedString("Quickly navigate to your common directories", comment: "") + "\n\n" + NSLocalizedString("Shortcut: Option + Space", comment: "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
    }
    
    @objc func showSearchPanel() {
        openPanel()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func createPanel() {
        // 计算屏幕中心位置
        let screenRect = NSScreen.main?.frame ?? .zero
        let width: CGFloat = 640
        let height: CGFloat = 490 // 略大于 View 的高度
        
        let initialRect = NSRect(
            x: (screenRect.width - width) / 2,
            y: (screenRect.height - height) / 2 + 100, // 稍微偏上一点视觉更好
            width: width,
            height: height
        )
        
        panel = KeyablePanel(
            contentRect: initialRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // 窗口属性配置
        panel.level = .mainMenu + 1 // 确保在普通窗口和全屏应用之上
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear 
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        
        // 监听来自 ViewModel 的关闭请求
        NotificationCenter.default.addObserver(forName: .closeWayPointWindow, object: nil, queue: .main) { _ in
            self.closePanel()
        }
        
        // 嵌入 SwiftUI 视图
        let contentView = WayPointView()
            .environmentObject(StorageManager.shared)
            .edgesIgnoringSafeArea(.all)
        
        panel.contentView = NSHostingView(rootView: contentView)
    }
    
    func togglePanel() {
        print("🔄 togglePanel: isVisible=\(panel?.isVisible ?? false), isActive=\(NSApp.isActive)")
        if let panel = panel, panel.isVisible && NSApp.isActive {
            closePanel()
        } else {
            // 在显示窗口前，记录当前活跃的应用 (为了 Inject 功能)
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                PathActionManager.shared.lastActiveApp = frontApp
                print("📱 Capturing frontmost app: \(frontApp.localizedName ?? "Unknown")")
            }
            openPanel()
        }
    }
    
    func openPanel() {
        print("📱 openPanel called")
        if panel == nil { createPanel() }
        
        // 1. 强制激活应用
        NSApp.activate(ignoringOtherApps: true)
        
        // 2. 显示并置顶窗口
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        
        // 3. 居中显示（可选，或者根据需要保持位置）
        panel.center()
        
        print("✅ Panel opened and activated")
        
        // 6. 多次尝试设置焦点，确保能够接收键盘输入
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            self.panel.makeKey()
            print("✅ Panel makeKey (attempt 1)")
            
            // 尝试将焦点设置到 contentView
            if let contentView = self.panel.contentView {
                self.panel.makeFirstResponder(contentView)
                print("✅ Set first responder to contentView")
            }
        }
        
        // 第二次尝试，确保焦点设置成功
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            self.panel.makeKey()
            print("✅ Panel makeKey (attempt 2)")
            print("🔍 Panel isKeyWindow: \(self.panel.isKeyWindow)")
            print("🔍 First responder: \(String(describing: self.panel.firstResponder))")
            
            // 尝试找到 TextField 并设置为第一响应者
            if let contentView = self.panel.contentView {
                self.findAndFocusTextField(in: contentView)
            }
        }
    }
    
    // 递归查找 TextField 并设置焦点
    private func findAndFocusTextField(in view: NSView) {
        for subview in view.subviews {
            if let textField = subview as? NSTextField {
                let result = panel.makeFirstResponder(textField)
                print("🎯 Found TextField and set as first responder: \(result)")
                print("🔍 TextField: \(textField)")
                return
            }
            // 递归查找子视图
            findAndFocusTextField(in: subview)
        }
    }
    
    func closePanel() {
        print("🚪 closePanel called")
        panel.orderOut(nil)
        // 重点：必须 hide，否则焦点无法交还给上一个 App，且 toggle 逻辑会失效
        NSApp.hide(nil)
    }
    
    // MARK: - NSWindowDelegate
    
    // 当窗口失去焦点（用户点击了别的地方）时自动隐藏
    func windowDidResignKey(_ notification: Notification) {
        closePanel()
    }
}