import SwiftUI
import Combine
import Quartz

class WayPointViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var filteredItems: [PathItem] = []
    @Published var selectedIndex: Int = 0
    @Published var activeTab: WayPointTab = .recent
    @Published var showSettings: Bool = false
    @Published var settingsTab: Int = 0
    @Published var isSearching: Bool = false
    @Published var scrollTargetId: UUID?
    
    // 弹窗相关状态
    @Published var renamingItem: PathItem? = nil
    @Published var renameInput: String = ""
    @Published var showingAddRule: Bool = false
    
    // 判断当前是否处于模态对话框状态
    var isModalActive: Bool {
        renamingItem != nil || showingAddRule || UpdateChecker.shared.isChecking || UpdateChecker.shared.showUpdateAlert
    }
    
    private var storage = StorageManager.shared
    @Published private var systemItems: [PathItem] = []
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Publishers.CombineLatest4($query, storage.$items, $systemItems, $activeTab)
            .map { (query, localItems, sysItems, activeTab) -> [PathItem] in
                var source = localItems
                if activeTab == .favorites { source = localItems.filter { $0.isFavorite } }
                if query.isEmpty { return Array(source.prefix(20)) }
                
                let scoredItems: [(item: PathItem, score: Int)] = source.compactMap { item in
                    let aliasScore = FuzzyMatcher.score(query: query, text: item.alias)
                    let pathScore = FuzzyMatcher.score(query: query, text: item.path)
                    if aliasScore > 0 || pathScore > 0 {
                        let finalScore = max(aliasScore * 2, pathScore)
                        return (item, finalScore)
                    }
                    return nil
                }
                
                let localPaths = Set(scoredItems.map { $0.item.path })
                let uniqueSysItems = sysItems.filter { !localPaths.contains($0.path) }
                let scoredSysItems = uniqueSysItems.compactMap { item -> (PathItem, Int)? in
                    let s = FuzzyMatcher.score(query: query, text: item.path)
                    return s > 0 ? (item, s) : nil
                }
                
                let allScored = scoredItems + scoredSysItems
                return allScored.sorted { a, b in
                    if a.score != b.score { return a.score > b.score }
                    if a.item.score != b.item.score { return a.item.score > b.item.score }
                    return a.item.path < b.item.path
                }.map { $0.item }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                self?.filteredItems = results
                self?.selectedIndex = 0
                self?.scrollTargetId = results.first?.id
            }
            .store(in: &cancellables)
            
        Publishers.Merge($query, $activeTab.map { _ in "" })
            .dropFirst().removeDuplicates()
            .sink { [weak self] _ in self?.systemItems = []; self?.isSearching = false; self?.selectedIndex = 0 }
            .store(in: &cancellables)
    }
    
    func switchTab() { activeTab = (activeTab == .recent) ? .favorites : .recent }
    
    func moveSelection(_ delta: Int) {
        let newIndex = selectedIndex + delta
        if newIndex >= 0 && newIndex < filteredItems.count {
            selectedIndex = newIndex; scrollTargetId = filteredItems[newIndex].id
        }
    }
    
    func startRenaming(item: PathItem) {
        renamingItem = item
        renameInput = item.alias
    }
    
    func submitRename() {
        guard let item = renamingItem else { return }
        StorageManager.shared.updateAlias(id: item.id, newAlias: renameInput)
        cancelRename()
    }
    
    func cancelRename() { renamingItem = nil; renameInput = "" }
    
    func performSystemSearch() {
        guard !query.isEmpty, !isSearching else { return }
        isSearching = true
        let q = query
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
            process.arguments = ["kMDItemContentType == 'public.folder' && kMDItemFSName == '*\(q)*'c"]
            let pipe = Pipe(); process.standardOutput = pipe
            try? process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let items = output.components(separatedBy: .newlines).filter{!$0.isEmpty}.prefix(50).map {
                    PathItem(path: $0, alias: URL(fileURLWithPath: $0).lastPathComponent, source: .finderHistory)
                }
                DispatchQueue.main.async { self?.systemItems = items; self?.isSearching = false }
            }
        }
    }
    
    func executeAction(type: ActionType, targetItem: PathItem? = nil) {
        // Equatable 检查：对于关联值枚举，直接用 switch 判断更稳健
        let isOpening = { if case .open = type { return true }; return false }()
        if isOpening && targetItem == nil && filteredItems.isEmpty { performSystemSearch(); return }
        
        let itemToUse = targetItem ?? (filteredItems.indices.contains(selectedIndex) ? filteredItems[selectedIndex] : nil)
        guard let item = itemToUse else { return }
        
        switch type {
        case .open:
            updateUsage(item); PathActionManager.shared.openInFinder(path: item.path); closeWindow()
        case .terminal:
            updateUsage(item); PathActionManager.shared.openInTerminal(path: item.path); closeWindow()
        case .copy:
            updateUsage(item); PathActionManager.shared.copyPath(path: item.path); closeWindow()
        case .inject:
            updateUsage(item); PathActionManager.shared.injectToDialog(path: item.path); closeWindow()
        case .editor:
            updateUsage(item); PathActionManager.shared.openInEditor(path: item.path); closeWindow()
        case .toggleFavorite:
            StorageManager.shared.toggleFavorite(id: item.id)
        case .exclude:
            StorageManager.shared.exclude(path: item.path)
            selectedIndex = max(0, min(selectedIndex, filteredItems.count - 1))
        case .preview:
            AppDelegate.shared.togglePreview(url: URL(fileURLWithPath: item.path))
        case .rename:
            startRenaming(item: item)
        case .contextAction(let action):
            executeContextAction(action, path: item.path)
        }
    }
    
    private func executeContextAction(_ action: ContextAction, path: String) {
        guard let cmd = action.command else { return }
        
        switch action.type {
        case .gitRemote:
            // 如果是 URL 类型动作
            if let url = URL(string: cmd) { NSWorkspace.shared.open(url) }
        case .shellCommand:
            // 如果是终端命令，我们先检查它是不是一个 URL (有些命令输出的是 URL)
            // 这里我们根据 Analyzer 传回的 type 细分逻辑
            PathActionManager.shared.runCommandInTerminal(command: cmd, path: path)
        }
        closeWindow()
    }
    
    private func updateUsage(_ item: PathItem) {
        StorageManager.shared.addOrUpdate(path: item.path, source: item.source)
        StorageManager.shared.recordJump(path: item.path)
    }
    
    private func closeWindow() {
        if QLPreviewPanel.sharedPreviewPanelExists() { QLPreviewPanel.shared().orderOut(nil) }
        NotificationCenter.default.post(name: Notification.Name("closeWayPointWindow"), object: nil)
    }
    
    enum ActionType: Equatable {
        case open, terminal, copy, inject, toggleFavorite, exclude, editor, preview, rename, contextAction(ContextAction)
    }
}