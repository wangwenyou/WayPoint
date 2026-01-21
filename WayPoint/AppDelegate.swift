import Cocoa
import SwiftUI
import Combine
import Quartz

extension Notification.Name {
    static let closeWayPointWindow = Notification.Name("closeWayPointWindow")
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) var shared: AppDelegate!
    
    var panel: KeyablePanel!
    var statusBarItem: NSStatusItem!
    var finderObserver = FinderObserver.shared
    var clipboardWatcher = ClipboardWatcher()
    private var menuCancellable: AnyCancellable?
    
    // 全局引用 ViewModel 以便从菜单栏控制 UI
    var viewModel: WayPointViewModel?
    
    var currentPreviewURL: URL?
    private var lastToggleTime: Date = Date.distantPast
    
    override init() {
        super.init()
        AppDelegate.shared = self
    }
    
    func togglePreview(url: URL) {
        let qlPanel = QLPreviewPanel.shared()!
        if QLPreviewPanel.sharedPreviewPanelExists() && qlPanel.isVisible && currentPreviewURL == url {
            qlPanel.orderOut(nil)
        } else {
            self.currentPreviewURL = url
            qlPanel.makeKeyAndOrderFront(nil)
            qlPanel.reloadData()
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()
        createPanel()
        FinderObserver.shared.start()
        HotKeyManager.shared.register()
        HotKeyManager.shared.onHotKeyTriggered = { [weak self] in
            DispatchQueue.main.async { self?.togglePanel() }
        }
        setupMenuSubscription()
    }
    
    private func setupMenuSubscription() {
        menuCancellable = StorageManager.shared.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in self?.updateStatusBarMenu(items: items) }
    }
    
    private func updateStatusBarMenu(items: [PathItem]) {
        guard let menu = statusBarItem.menu else { return }
        menu.removeAllItems()
        
        // 顶部预设
        menu.addItem(NSMenuItem(title: NSLocalizedString("Show Search Window", comment: ""), action: #selector(showSearchPanel), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: NSLocalizedString("Settings...", comment: ""), action: #selector(showAbout), keyEquivalent: ","))
        
        menu.addItem(NSMenuItem.separator())
        
        // 最近访问
        let topItems = items.sorted { $0.score > $1.score }.prefix(5)
        for item in topItems {
            let menuItem = NSMenuItem(title: item.alias, action: #selector(openRecentItem(_:)), keyEquivalent: "")
            if let image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil) {
                image.isTemplate = true
                menuItem.image = image
            }
            menuItem.representedObject = item.path
            menuItem.toolTip = item.path
            menu.addItem(menuItem)
        }
        
        if !topItems.isEmpty { menu.addItem(NSMenuItem.separator()) }
        
        // 底部退出
        menu.addItem(NSMenuItem(title: NSLocalizedString("Quit WayPoint", comment: ""), action: #selector(quitApp), keyEquivalent: "q"))
    }
    
    @objc func openRecentItem(_ sender: NSMenuItem) {
        if let path = sender.representedObject as? String {
            PathActionManager.shared.openInFinder(path: path)
            StorageManager.shared.recordJump(path: path)
            StorageManager.shared.addOrUpdate(path: path, source: .manual)
        }
    }
    
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusBarItem.button {
            if let image = NSImage(systemSymbolName: "location.circle.fill", accessibilityDescription: "WayPoint") {
                image.isTemplate = true
                button.image = image
            } else { button.title = "WP" }
        }
        statusBarItem.isVisible = true
        statusBarItem.menu = NSMenu()
    }
    
    @objc func showAbout() {
        // 跳转到设置页面的“关于”标签
        viewModel?.showSettings = true
        viewModel?.settingsTab = 4 // About 标签的 tag 是 4
        openPanel()
    }
    
    @objc func showSearchPanel() {
        viewModel?.showSettings = false
        openPanel()
    }
    
    @objc func quitApp() { NSApplication.shared.terminate(nil) }
    
    private func createPanel() {
        let screenRect = NSScreen.main?.frame ?? .zero
        let width: CGFloat = 720
        let height: CGFloat = 540
        let initialRect = NSRect(x: (screenRect.width - width) / 2, y: (screenRect.height - height) / 2 + 100, width: width, height: height)
        
        panel = KeyablePanel(contentRect: initialRect, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.level = .mainMenu + 1
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.delegate = self
        
        NotificationCenter.default.addObserver(forName: .closeWayPointWindow, object: nil, queue: .main) { _ in self.closePanel() }
        
        // 初始化 ViewModel 并保存引用
        let vm = WayPointViewModel()
        self.viewModel = vm
        
        let contentView = WayPointView(vm: vm).environmentObject(StorageManager.shared).edgesIgnoringSafeArea(.all)
        panel.contentView = NSHostingView(rootView: contentView)
    }
    
    func togglePanel() {
        let now = Date()
        if now.timeIntervalSince(lastToggleTime) < 0.2 { return }
        lastToggleTime = now
        
        if panel.isVisible && panel.isKeyWindow { closePanel() }
        else {
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                PathActionManager.shared.lastActiveApp = frontApp
            }
            openPanel()
        }
    }
    
    func openPanel() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.center()
    }
    
    func closePanel() {
        if QLPreviewPanel.sharedPreviewPanelExists() { QLPreviewPanel.shared().orderOut(nil) }
        panel.orderOut(nil)
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if let qlPanel = QLPreviewPanel.shared(), qlPanel.isVisible { return }
        
        // 如果正在重命名或添加规则，不要关闭窗口
        if let vm = viewModel, vm.isModalActive { return }
        
        closePanel()
    }
}