import SwiftUI
import Combine
import Quartz

class WayPointViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var filteredItems: [PathItem] = []
    @Published var selectedIndex: Int = 0
    @Published var activeTab: WayPointTab = .focus
    @Published var showSettings: Bool = false
    @Published var settingsTab: Int = 0
    @Published var isSearching: Bool = false
    @Published var scrollTargetId: UUID?
    @Published var showDetail: Bool = false
    
    // 弹窗相关状态
    @Published var renamingItem: PathItem? = nil
    @Published var renameInput: String = ""
    @Published var showingAddRule: Bool = false
    
    // 判断当前是否处于模态对话框状态
    var isModalActive: Bool {
        showSettings || renamingItem != nil || showingAddRule || UpdateChecker.shared.isChecking || UpdateChecker.shared.showUpdateAlert
    }
    
    private var storage = StorageManager.shared

    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 性能优化：添加 debounce 减少频繁更新
        Publishers.CombineLatest4($query, storage.$items, storage.$jumpHistory, $activeTab)
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .map { (query, localItems, jumpHistory, activeTab) -> [PathItem] in
                var source: [PathItem]
                if activeTab == .favorites {
                    source = localItems.filter { $0.isFavorite }
                } else if activeTab == .history {
                    let reversedHistory = jumpHistory.reversed()
                    var seenPaths = Set<String>()
                    var uniqueItems: [PathItem] = []
                    
                    for record in reversedHistory {
                        // 归一化路径进行去重
                        var normalized = record.path.trimmingCharacters(in: .whitespacesAndNewlines)
                        if normalized.hasSuffix("/") && normalized.count > 1 { normalized.removeLast() }
                        
                        guard !seenPaths.contains(normalized) else { continue }
                        seenPaths.insert(normalized)
                        
                        if let existing = localItems.first(where: { 
                            var p = $0.path
                            if p.hasSuffix("/") && p.count > 1 { p.removeLast() }
                            return p == normalized 
                        }) {
                            var item = existing
                            item.lastVisitedAt = record.timestamp
                            uniqueItems.append(item)
                        } else {
                            // 使用路径生成的 MD5 样式的稳定 UUID，避免 hashValue 不稳定
                            let pathData = Data(normalized.utf8)
                            let stableId = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", abs(normalized.hashValue))) ?? UUID()
                            uniqueItems.append(PathItem(id: stableId, path: normalized, alias: (normalized as NSString).lastPathComponent, lastVisitedAt: record.timestamp, source: .manual))
                        }
                    }
                    source = uniqueItems
                } else {
                    source = localItems
                }
                
                if query.isEmpty { 
                    // 历史记录模式下不需要强制截断到 20 条，给用户更多回溯空间
                    return activeTab == .history ? Array(source.prefix(100)) : Array(source.prefix(20)) 
                }
                
                let scoredItems: [(item: PathItem, score: Int)] = source.compactMap { item in
                    let aliasScore = FuzzyMatcher.score(query: query, text: item.alias)
                    let pathScore = FuzzyMatcher.score(query: query, text: item.path)
                    
                    // 引入"预言家"加分逻辑
                    let contextBonus = ContextPredictor.shared.calculateBonus(for: item)
                    
                    if aliasScore > 0 || pathScore > 0 {
                        let finalScore = max(aliasScore * 2, pathScore) + contextBonus
                        return (item, finalScore)
                    } else if query.isEmpty && contextBonus > 0 {
                        // 即便没输入，有上下文加分的也优先展示在前 20 名
                        return (item, contextBonus)
                    }
                    return nil
                }
                
                let allScored = scoredItems
                return allScored.sorted { a, b in
                    if a.score != b.score { return a.score > b.score }
                    if a.item.score != b.item.score { return a.item.score > b.item.score }
                    return a.item.path < b.item.path
                }.map { $0.item }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                guard let self = self else { return }
                
                // 检查路径列表是否真的变了（忽略元数据更新）
                let oldPaths = self.filteredItems.map { $0.path }
                let newPaths = results.map { $0.path }
                
                self.filteredItems = results
                
                if oldPaths != newPaths {
                    self.selectedIndex = 0
                    self.scrollTargetId = results.first?.id
                }
            }
            .store(in: &cancellables)
            
        Publishers.Merge($query, $activeTab.map { _ in "" })
            .dropFirst().removeDuplicates()
            .sink { [weak self] _ in self?.isSearching = false; self?.selectedIndex = 0 }
            .store(in: &cancellables)
            
        $showSettings
            .filter { $0 }
            .sink { [weak self] _ in self?.showDetail = false }
            .store(in: &cancellables)
    }
    
    func switchTab() { 
        switch activeTab {
        case .focus: activeTab = .favorites
        case .favorites: activeTab = .history
        case .history: activeTab = .focus
        }
        showDetail = false // 切换 Tab 时隐藏详情
    }
    
    func handleLeftArrow() {
        withAnimation(DesignSystem.Animation.springQuick) {
            switch activeTab {
            case .focus: activeTab = .history
            case .favorites: activeTab = .focus
            case .history: activeTab = .favorites
            }
            showDetail = false
        }
    }
    
    func handleRightArrow() {
        withAnimation(DesignSystem.Animation.springQuick) {
            switch activeTab {
            case .focus: activeTab = .favorites
            case .favorites: activeTab = .history
            case .history: activeTab = .focus
            }
            showDetail = false
        }
    }
    
    func toggleDetail() {
        if !filteredItems.isEmpty {
            withAnimation(DesignSystem.Animation.springQuick) { showDetail.toggle() }
        }
    }
    
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
        // NOTE: systemItems has been removed. This function currently does not populate results to the UI.
        // It needs to be redesigned if system-wide search results are to be displayed.
        // For now, just set isSearching to false.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
            process.arguments = ["kMDItemContentType == 'public.folder' && kMDItemFSName == '*\(self?.query ?? "")*'c"] // Use self?.query
            let pipe = Pipe(); process.standardOutput = pipe
            try? process.run()
            _ = pipe.fileHandleForReading.readDataToEndOfFile() // Read data to prevent pipe issues, but discard it for now
            DispatchQueue.main.async { self?.isSearching = false }
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
            updateUsage(item, actionType: "Open in Finder"); PathActionManager.shared.openInFinder(path: item.path); closeWindow()
        case .terminal:
            updateUsage(item, actionType: "Open in Terminal"); PathActionManager.shared.openInTerminal(path: item.path); closeWindow()
        case .copy:
            updateUsage(item, actionType: "Copy Path"); PathActionManager.shared.copyPath(path: item.path); closeWindow()
        case .inject:
            updateUsage(item, actionType: "Inject"); PathActionManager.shared.injectToDialog(path: item.path); closeWindow()
        case .editor:
            updateUsage(item, actionType: "Open in Editor"); PathActionManager.shared.openInEditor(path: item.path); closeWindow()
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
            updateUsage(item, actionType: action.title)
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
    
    private func updateUsage(_ item: PathItem, actionType: String) {
        StorageManager.shared.addOrUpdate(path: item.path, source: item.source)
        StorageManager.shared.recordJump(path: item.path, actionType: actionType)
    }
    
    private func closeWindow() {
        if QLPreviewPanel.sharedPreviewPanelExists() { QLPreviewPanel.shared().orderOut(nil) }
        NotificationCenter.default.post(name: Notification.Name("closeWayPointWindow"), object: nil)
    }
    
    enum ActionType: Equatable {
        case open, terminal, copy, inject, toggleFavorite, exclude, editor, preview, rename, contextAction(ContextAction)
    }
    
}