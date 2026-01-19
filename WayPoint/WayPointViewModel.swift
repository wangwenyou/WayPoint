import SwiftUI
import Combine

class WayPointViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var filteredItems: [PathItem] = []
    @Published var selectedIndex: Int = 0
    @Published var isSearching: Bool = false
    
    @Published var activeTab: WayPointTab = .recent
    
    // 用于通知 View 滚动到指定 ID
    @Published var scrollTargetId: UUID?
    
    private var storage = StorageManager.shared
    @Published private var systemItems: [PathItem] = [] // 系统搜索结果
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 响应式管道：当 query, storage.items, systemItems 或 activeTab 变化时，重新过滤并排序
        Publishers.CombineLatest4($query, storage.$items, $systemItems, $activeTab)
            .map { (query, localItems, sysItems, activeTab) -> [PathItem] in
                var filtered = localItems
                
                // 1. 标签过滤 (如果是 Favorites 标签，只显示收藏项)
                if activeTab == .favorites {
                    filtered = localItems.filter { $0.isFavorite }
                }
                
                if query.isEmpty {
                    // 空搜索时：显示当前列表的前 20 个项
                    return Array(filtered.prefix(20))
                } else {
                    let lowerQuery = query.localizedLowercase
                    
                    // 2. 本地筛选
                    let matchedLocal = filtered.filter { item in
                        FuzzyMatcher.match(query: query, text: item.alias) ||
                        FuzzyMatcher.match(query: query, text: item.path)
                    }
                    
                    // 3. 合并系统搜索结果 (去重：如果本地已经有了，就不显示系统的)
                    let finalLocal: [PathItem]
                    if activeTab == .favorites {
                        finalLocal = matchedLocal
                    } else {
                        let localPaths = Set(matchedLocal.map { $0.path })
                        let uniqueSysItems = sysItems.filter { !localPaths.contains($0.path) }
                        finalLocal = matchedLocal + uniqueSysItems
                    }
                    
                    // 4. 智能排序
                    return finalLocal.sorted { item1, item2 in
                        let alias1 = item1.alias.localizedLowercase
                        let alias2 = item2.alias.localizedLowercase
                        
                        // 规则 A: 别名完全匹配 (Exact Match)
                        if alias1 == lowerQuery && alias2 != lowerQuery { return true }
                        if alias1 != lowerQuery && alias2 == lowerQuery { return false }
                        
                        // 规则 B: 别名以 query 开头 (Prefix Match)
                        let prefix1 = alias1.hasPrefix(lowerQuery)
                        let prefix2 = alias2.hasPrefix(lowerQuery)
                        if prefix1 && !prefix2 { return true }
                        if !prefix1 && prefix2 { return false }
                        
                        // 规则 C: 别名包含 query (Contains Match)
                        let contains1 = alias1.contains(lowerQuery)
                        let contains2 = alias2.contains(lowerQuery)
                        if contains1 && !contains2 { return true }
                        if !contains1 && contains2 { return false }
                        
                        // 规则 D: 权重/分数排序
                         if item1.score != item2.score {
                             return item1.score > item2.score
                         }
                         
                         return item1.path < item2.path
                    }
                }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                self?.filteredItems = results
                self?.selectedIndex = 0
                self?.scrollTargetId = results.first?.id
            }
            .store(in: &cancellables)
            
        // 当 query 或 activeTab 变化时，清空之前的系统搜索结果
        Publishers.Merge($query, $activeTab.map { _ in "" })
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.systemItems = []
                self?.isSearching = false
                self?.selectedIndex = 0
            }
            .store(in: &cancellables)
    }
    
    // 切换 Tab
    func switchTab() {
        activeTab = (activeTab == .recent) ? .favorites : .recent
    }
    
    // 处理键盘上下键选择
    func moveSelection(_ delta: Int) {
        let newIndex = selectedIndex + delta
        if newIndex >= 0 && newIndex < filteredItems.count {
            selectedIndex = newIndex
            // 更新滚动目标 ID
            scrollTargetId = filteredItems[newIndex].id
        }
    }
    
    // 执行系统搜索
    func performSystemSearch() {
        guard !query.isEmpty, !isSearching else { return }
        
        isSearching = true
        let currentQuery = query
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
            process.arguments = ["kMDItemContentType == 'public.folder' && kMDItemFSName == '*\(currentQuery)*'c"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let paths = output.components(separatedBy: .newlines)
                        .filter { !$0.isEmpty }
                        .prefix(50)
                    
                    let items = paths.map { path -> PathItem in
                        let url = URL(fileURLWithPath: path)
                        return PathItem(path: path, alias: url.lastPathComponent, visitCount: 0, lastVisitedAt: Date(), isFavorite: false, source: .finderHistory)
                    }
                    
                    DispatchQueue.main.async {
                        self?.systemItems = items
                        self?.isSearching = false
                    }
                }
            } catch {
                print("System search failed: \(error)")
                DispatchQueue.main.async {
                    self?.isSearching = false
                }
            }
        }
    }
    
    // 执行操作
    func executeAction(type: ActionType, targetItem: PathItem? = nil) {
        if type == .open && targetItem == nil && filteredItems.isEmpty {
            performSystemSearch()
            return
        }
        
        let itemToUse: PathItem
        if let target = targetItem {
            itemToUse = target
        } else {
            guard filteredItems.indices.contains(selectedIndex) else { return }
            itemToUse = filteredItems[selectedIndex]
        }
        
        switch type {
        case .open:
            StorageManager.shared.addOrUpdate(path: itemToUse.path, source: itemToUse.source)
            PathActionManager.shared.openInFinder(path: itemToUse.path)
            closeWindow()
        case .terminal:
            StorageManager.shared.addOrUpdate(path: itemToUse.path, source: itemToUse.source)
            PathActionManager.shared.openInTerminal(path: itemToUse.path)
            closeWindow()
        case .copy:
            StorageManager.shared.addOrUpdate(path: itemToUse.path, source: itemToUse.source)
            PathActionManager.shared.copyPath(path: itemToUse.path)
            closeWindow()
        case .inject:
            StorageManager.shared.addOrUpdate(path: itemToUse.path, source: itemToUse.source)
            PathActionManager.shared.injectToDialog(path: itemToUse.path)
            closeWindow()
        case .toggleFavorite:
            StorageManager.shared.toggleFavorite(id: itemToUse.id)
        case .exclude:
            StorageManager.shared.exclude(path: itemToUse.path)
            selectedIndex = max(0, min(selectedIndex, filteredItems.count - 1))
        case .editor:
            StorageManager.shared.addOrUpdate(path: itemToUse.path, source: itemToUse.source)
            PathActionManager.shared.openInEditor(path: itemToUse.path)
            closeWindow()
        }
    }
    
    private func closeWindow() {
        NotificationCenter.default.post(name: Notification.Name("closeWayPointWindow"), object: nil)
    }
    
    enum ActionType { case open, terminal, copy, inject, toggleFavorite, exclude, editor }
}
