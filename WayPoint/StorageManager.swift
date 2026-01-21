import Foundation
import Combine
import AppKit

struct JumpRecord: Codable {
    let path: String
    let timestamp: Date
}

// 提取为全局公共模型
struct AppOption: Identifiable, Equatable {
    let id: String // BundleID
    let name: String
}

class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    @Published var items: [PathItem] = []
    @Published var excludedPaths: Set<String> = []
    @Published var jumpHistory: [JumpRecord] = []
    @Published var contextRules: [ContextRule] = [] // 用户自定义规则
    
    @Published var preferredEditor: String {
        didSet { UserDefaults.standard.set(preferredEditor, forKey: "PreferredEditorV2") }
    }
    @Published var preferredTerminal: String {
        didSet { UserDefaults.standard.set(preferredTerminal, forKey: "PreferredTerminalV2") }
    }
    @Published var customEditorName: String {
        didSet { UserDefaults.standard.set(customEditorName, forKey: "CustomEditorName") }
    }
    @Published var customTerminalName: String {
        didSet { UserDefaults.standard.set(customTerminalName, forKey: "CustomTerminalName") }
    }
    
    private let fileURL: URL
    private let excludeURL: URL
    private let historyURL: URL
    private let rulesURL: URL
    
    private init() {
        self.preferredEditor = UserDefaults.standard.string(forKey: "PreferredEditorV2") ?? "com.microsoft.VSCode"
        self.preferredTerminal = UserDefaults.standard.string(forKey: "PreferredTerminalV2") ?? "dev.warp.Warp-Stable"
        self.customEditorName = UserDefaults.standard.string(forKey: "CustomEditorName") ?? ""
        self.customTerminalName = UserDefaults.standard.string(forKey: "CustomTerminalName") ?? ""
        
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appDir = urls[0].appendingPathComponent("WayPoint")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        
        self.fileURL = appDir.appendingPathComponent("waypoints.json")
        self.excludeURL = appDir.appendingPathComponent("excluded_paths.json")
        self.historyURL = appDir.appendingPathComponent("jump_history.json")
        self.rulesURL = appDir.appendingPathComponent("context_rules.json")
        
        Task(priority: .userInitiated) { await loadDataAsync() }
    }
    
    private func loadDataAsync() async {
        // 加载规则
        if let data = try? Data(contentsOf: rulesURL),
           let decoded = try? JSONDecoder().decode([ContextRule].self, from: data) {
            await MainActor.run { self.contextRules = decoded }
        } else {
            await MainActor.run { self.contextRules = ContextRule.defaults }
        }
        
        if let data = try? Data(contentsOf: excludeURL), let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            await MainActor.run { self.excludedPaths = decoded }
        }
        if let data = try? Data(contentsOf: historyURL), let decoded = try? JSONDecoder().decode([JumpRecord].self, from: data) {
            await MainActor.run { self.jumpHistory = decoded }
        }
        var loadedItems: [PathItem] = []
        if let data = try? Data(contentsOf: fileURL), let decoded = try? JSONDecoder().decode([PathItem].self, from: data) {
            loadedItems = decoded
        }
        let autojumpItems = await parseAutojump()
        for item in autojumpItems {
            if let index = loadedItems.firstIndex(where: { $0.path == item.path }) {
                if item.visitCount > loadedItems[index].visitCount { loadedItems[index].visitCount = item.visitCount }
            } else { loadedItems.append(item) }
        }
        let finalItems = loadedItems.sorted { $0.score > $1.score }
        await MainActor.run { self.items = finalItems }
    }
    
    func resetRulesToDefaults() {
        self.contextRules = ContextRule.defaults
        saveRules()
        FolderAnalyzer.shared.clearCache()
    }
    
    func getEditorDisplayName() -> String {
        let presets = ["com.microsoft.VSCode": "Visual Studio Code", "com.todesktop.230313mzl4w4u92": "Cursor", "com.sublimetext.4": "Sublime Text", "dev.zed.Zed": "Zed", "com.jetbrains.intellij": "IntelliJ IDEA", "com.apple.TextEdit": "TextEdit"]
        return presets[preferredEditor] ?? (customEditorName.isEmpty ? preferredEditor : customEditorName)
    }
    
    func getTerminalDisplayName() -> String {
        let presets = ["com.googlecode.iterm2": "iTerm2", "dev.warp.Warp-Stable": "Warp", "com.apple.Terminal": "Terminal", "com.github.wez.wezterm": "WezTerm"]
        return presets[preferredTerminal] ?? (customTerminalName.isEmpty ? preferredTerminal : customTerminalName)
    }
    
    func saveRules() {
        if let encoded = try? JSONEncoder().encode(contextRules) { try? encoded.write(to: rulesURL) }
        FolderAnalyzer.shared.clearCache()
        
        // 关键修复：规则变更后，重置内存中所有项目的 actions，并对前 30 个常用项立即触发异步刷新
        DispatchQueue.main.async {
            for i in 0..<self.items.count {
                self.items[i].actions = []
            }
            // 立即刷新前 30 个项目，确保 UI 响应迅速
            for item in self.items.prefix(30) {
                self.refreshMetadata(for: item.id)
            }
        }
    }
    
    private func parseAutojump() async -> [PathItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let potentialURLs = [
            home.appendingPathComponent(".local/share/autojump/autojump.txt"),
            home.appendingPathComponent("Library/autojump/autojump.txt")
        ]
        var newItems: [PathItem] = []
        for autojumpURL in potentialURLs {
            guard FileManager.default.fileExists(atPath: autojumpURL.path) else { continue }
            guard let content = try? String(contentsOf: autojumpURL, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines)
            for line in lines where !line.isEmpty {
                let parts = line.components(separatedBy: "\t")
                guard parts.count >= 2, let weight = Double(parts[0]) else { continue }
                let path = parts[1]
                let cp = path.trimmingCharacters(in: .whitespacesAndNewlines)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: cp, isDirectory: &isDir), isDir.boolValue {
                    newItems.append(PathItem(path: cp, alias: (cp as NSString).lastPathComponent, visitCount: Int(weight), source: .manual))
                }
            }
        }
        return newItems
    }
    
    func recordJump(path: String) {
        let record = JumpRecord(path: path, timestamp: Date())
        DispatchQueue.main.async {
            self.jumpHistory.append(record)
            if self.jumpHistory.count > 1000 { self.jumpHistory.removeFirst() }
            self.saveHistory()
        }
    }
    
    func addOrUpdate(path: String, source: PathItem.SourceType) {
        let cp = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if excludedPaths.contains(cp) { return }
        DispatchQueue.main.async {
            let id: UUID
            if let index = self.items.firstIndex(where: { $0.path == cp }) {
                self.items[index].visitCount += 1
                self.items[index].lastVisitedAt = Date()
                id = self.items[index].id
            } else {
                let newItem = PathItem(path: cp, alias: (cp as NSString).lastPathComponent, source: source)
                self.items.append(newItem)
                id = newItem.id
            }
            self.items.sort { $0.score > $1.score }; self.save(); self.refreshMetadata(for: id)
        }
    }
    
    func refreshMetadata(for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let path = items[index].path
        Task {
            let result = await FolderAnalyzer.shared.analyze(path: path)
            await MainActor.run {
                if let idx = self.items.firstIndex(where: { $0.id == id }) {
                    self.items[idx].tags = result.tags
                    self.items[idx].technology = result.technology
                    self.items[idx].statusSummary = result.statusSummary
                    self.items[idx].actions = result.actions
                }
            }
        }
    }
    
    func exclude(path: String) {
        DispatchQueue.main.async {
            self.excludedPaths.insert(path)
            self.items.removeAll(where: { $0.path == path }); self.save()
        }
    }
    
    func unexclude(path: String) {
        DispatchQueue.main.async { self.excludedPaths.remove(path); self.save() }
    }
    
    func toggleFavorite(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isFavorite.toggle(); items.sort { $0.score > $1.score }; save()
        }
    }
    
    func updateAlias(id: UUID, newAlias: String) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            let finalName = newAlias.trimmingCharacters(in: .whitespacesAndNewlines)
            // 如果别名为空，恢复为文件名
            if finalName.isEmpty {
                items[index].alias = (items[index].path as NSString).lastPathComponent
            } else {
                items[index].alias = finalName
            }
            save()
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(items) { try? encoded.write(to: fileURL) }
        if let encoded = try? JSONEncoder().encode(excludedPaths) { try? encoded.write(to: excludeURL) }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(jumpHistory) { try? encoded.write(to: historyURL) }
    }
}
