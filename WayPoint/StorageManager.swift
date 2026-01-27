import Foundation
import Combine
import AppKit

struct JumpRecord: Codable, Identifiable {
    var id: UUID = UUID()
    let path: String
    var timestamp: Date
    let actionType: String // 如 "Inject", "Terminal", "Editor", "Rule: npm start"
    
    enum CodingKeys: String, CodingKey {
        case path, timestamp, actionType
    }
    
    init(path: String, timestamp: Date, actionType: String) {
        self.path = path
        self.timestamp = timestamp
        self.actionType = actionType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        actionType = try container.decode(String.self, forKey: .actionType)
        id = UUID()
    }
}

// 提取为全局公共模型
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return NSLocalizedString("System", comment: "")
        case .light: return NSLocalizedString("Light", comment: "")
        case .dark: return NSLocalizedString("Dark", comment: "")
        }
    }
}
struct AppOption: Identifiable, Equatable {
    let id: String // BundleID
    let name: String
}

enum StandardAction: String, CaseIterable, Codable, Identifiable {
    case inject, open, preview, terminal, editor, copy, toggleFavorite, exclude, rename
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .inject: return "arrowshape.turn.up.right.fill"
        case .open: return "folder"
        case .preview: return "eye"
        case .terminal: return "terminal"
        case .editor: return "chevron.left.forwardslash.chevron.right"
        case .copy: return "doc.on.clipboard"
        case .toggleFavorite: return "star"
        case .exclude: return "eye.slash"
        case .rename: return "pencil"
        }
    }
    
    var label: String {
        switch self {
        case .inject: return NSLocalizedString("Inject to Dialog", comment: "")
        case .open: return NSLocalizedString("Open in Finder", comment: "")
        case .preview: return NSLocalizedString("Quick Look Preview", comment: "")
        case .terminal: return NSLocalizedString("Open in Terminal", comment: "")
        case .editor: return NSLocalizedString("Open in Editor", comment: "")
        case .copy: return NSLocalizedString("Copy Path", comment: "")
        case .toggleFavorite: return NSLocalizedString("Favorite", comment: "")
        case .exclude: return NSLocalizedString("Exclude Path", comment: "")
        case .rename: return NSLocalizedString("Set Alias", comment: "")
        }
    }
}

class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    @Published var items: [PathItem] = []
    @Published var excludedPaths: Set<String> = []
    @Published var jumpHistory: [JumpRecord] = []
    @Published var contextRules: [ContextRule] = [] // 用户自定义规则
    @Published var predictorRules: [AppContextRule] = [] // 预言家规则
    @Published var techDetectionRules: [TechDetectionRule] = [] // 智能标签规则
    
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
    @Published var showMenuBarWidget: Bool {
        didSet { UserDefaults.standard.set(showMenuBarWidget, forKey: "ShowMenuBarWidgetV1") }
    }
    @Published var showVersionNumber: Bool {
        didSet { 
            UserDefaults.standard.set(showVersionNumber, forKey: "ShowVersionNumberV1")
            FolderAnalyzer.shared.clearCache()
            DispatchQueue.main.async {
                for item in self.items.prefix(30) {
                    self.refreshMetadata(for: item.id)
                }
            }
        }
    }
    @Published var launchAtLogin: Bool {
        didSet { 
            UserDefaults.standard.set(launchAtLogin, forKey: "LaunchAtLogin")
            LaunchAtLoginManager.shared.updateStatus()
        }
    }
    
    // Interface Customization
    @Published var showResultTags: Bool {
        didSet { UserDefaults.standard.set(showResultTags, forKey: "ShowResultTags") }
    }
    @Published var showResultScore: Bool {
        didSet { UserDefaults.standard.set(showResultScore, forKey: "ShowResultScore") }
    }
    @Published var showResultInfo: Bool {
        didSet { UserDefaults.standard.set(showResultInfo, forKey: "ShowResultInfo") }
    }
    @Published var enabledToolbarActions: [StandardAction] {
        didSet {
            if let data = try? JSONEncoder().encode(enabledToolbarActions) {
                UserDefaults.standard.set(data, forKey: "EnabledToolbarActions")
            }
        }
    }
    @Published var appAppearance: AppAppearance {
        didSet { UserDefaults.standard.set(appAppearance.rawValue, forKey: "AppAppearance") }
    }
    
    // Scoring Algorithm
    @Published var weightFrequency: Double {
        didSet { UserDefaults.standard.set(weightFrequency, forKey: "WeightFreq"); recalculateScores() }
    }
    @Published var weightRecency: Double {
        didSet { UserDefaults.standard.set(weightRecency, forKey: "WeightRecency"); recalculateScores() }
    }
    @Published var weightPrediction: Double {
        didSet { UserDefaults.standard.set(weightPrediction, forKey: "WeightPrediction"); recalculateScores() }
    }
    @Published var customPathWeights: [String: Double] = [:] {
        didSet { saveScoringWeights(); recalculateScores() }
    }
    
    private let fileURL: URL
    private let excludeURL: URL
    private let historyURL: URL
    private let rulesURL: URL
    private let predictorRulesURL: URL
    private let techRulesURL: URL
    private let scoringWeightsURL: URL
    
    private init() {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appDir = urls[0].appendingPathComponent("WayPoint")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        
        self.fileURL = appDir.appendingPathComponent("waypoints.json")
        self.excludeURL = appDir.appendingPathComponent("excluded_paths.json")
        self.historyURL = appDir.appendingPathComponent("jump_history.json")
        self.rulesURL = appDir.appendingPathComponent("context_rules.json")
        self.predictorRulesURL = appDir.appendingPathComponent("predictor_rules.json")
        self.techRulesURL = appDir.appendingPathComponent("tech_rules.json")
        self.scoringWeightsURL = appDir.appendingPathComponent("scoring_weights.json")

        self.preferredEditor = UserDefaults.standard.string(forKey: "PreferredEditorV2") ?? "com.microsoft.VSCode"
        self.preferredTerminal = UserDefaults.standard.string(forKey: "PreferredTerminalV2") ?? "dev.warp.Warp-Stable"
        self.customEditorName = UserDefaults.standard.string(forKey: "CustomEditorName") ?? ""
        self.customTerminalName = UserDefaults.standard.string(forKey: "CustomTerminalName") ?? ""
        self.showMenuBarWidget = UserDefaults.standard.object(forKey: "ShowMenuBarWidgetV1") as? Bool ?? true
        self.showVersionNumber = UserDefaults.standard.object(forKey: "ShowVersionNumberV1") as? Bool ?? true
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "LaunchAtLogin")
        
        self.showResultTags = UserDefaults.standard.object(forKey: "ShowResultTags") as? Bool ?? true
        self.showResultScore = UserDefaults.standard.object(forKey: "ShowResultScore") as? Bool ?? true
        self.showResultInfo = UserDefaults.standard.object(forKey: "ShowResultInfo") as? Bool ?? true
        
        let appearanceRaw = UserDefaults.standard.string(forKey: "AppAppearance") ?? "system"
        self.appAppearance = AppAppearance(rawValue: appearanceRaw) ?? .system
        
        var wFreq = UserDefaults.standard.double(forKey: "WeightFreq")
        if wFreq == 0 { wFreq = 1.0 }
        self.weightFrequency = wFreq
        
        var wRec = UserDefaults.standard.double(forKey: "WeightRecency")
        if wRec == 0 { wRec = 1.0 }
        self.weightRecency = wRec
        
        var wPred = UserDefaults.standard.double(forKey: "WeightPrediction")
        if wPred == 0 && UserDefaults.standard.object(forKey: "WeightPrediction") == nil { wPred = 1.0 }
        self.weightPrediction = wPred
        
        if let data = UserDefaults.standard.data(forKey: "EnabledToolbarActions"),
           let actions = try? JSONDecoder().decode([StandardAction].self, from: data) {
            self.enabledToolbarActions = actions
        } else {
            self.enabledToolbarActions = StandardAction.allCases
        }
        
        // 性能优化：快速启动路径 - 优先加载关键数据
        Task(priority: .userInitiated) { await loadEssentialData() }
        
        // 完整数据加载延迟执行
        Task(priority: .background) { await loadFullDataAsync() }
    }
    
    // 快速加载关键数据（启动时立即执行）
    private func loadEssentialData() async {
        // 1. 优先加载规则（UI 需要）
        if let data = try? Data(contentsOf: rulesURL),
           let decoded = try? JSONDecoder().decode([ContextRule].self, from: data) {
            await MainActor.run { self.contextRules = decoded }
        } else {
            await MainActor.run { self.contextRules = ContextRule.defaults }
        }
        
        if let data = try? Data(contentsOf: predictorRulesURL),
           let decoded = try? JSONDecoder().decode([AppContextRule].self, from: data) {
            await MainActor.run { self.predictorRules = decoded }
        } else {
            await MainActor.run { self.predictorRules = ContextPredictor.defaultRules }
        }
        
        if let data = try? Data(contentsOf: techRulesURL),
           let decoded = try? JSONDecoder().decode([TechDetectionRule].self, from: data) {
            await MainActor.run { self.techDetectionRules = decoded }
        } else {
            await MainActor.run { self.techDetectionRules = TechDetectionRule.defaults }
        }
        
        // 2. 只加载前 20 个高频路径（快速启动）
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([PathItem].self, from: data) {
            // 简单去重
            var mergedMap: [String: PathItem] = [:]
            for item in decoded {
                var normalized = item.path
                if normalized.hasSuffix("/") && normalized.count > 1 { normalized.removeLast() }
                
                if let existing = mergedMap[normalized] {
                    mergedMap[normalized]!.visitCount = max(existing.visitCount, item.visitCount)
                    if item.lastVisitedAt > existing.lastVisitedAt {
                        mergedMap[normalized]!.lastVisitedAt = item.lastVisitedAt
                    }
                    if item.isFavorite { mergedMap[normalized]!.isFavorite = true }
                } else {
                    mergedMap[normalized] = item
                }
            }
            
            let topItems = Array(mergedMap.values.sorted { $0.score > $1.score }.prefix(20))
            await MainActor.run { 
                self.items = topItems
                // 立即刷新前 5 个项目的元数据
                for item in topItems.prefix(5) {
                    self.refreshMetadata(for: item.id, priority: .userInitiated)
                }
            }
        }
    }
    
    // 完整数据加载（后台执行）
    private func loadFullDataAsync() async {
        // 加载评分权重字典
        if let data = try? Data(contentsOf: scoringWeightsURL),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            await MainActor.run { self.customPathWeights = decoded }
        }
        
        // 加载排除路径
        if let data = try? Data(contentsOf: excludeURL), 
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            await MainActor.run { self.excludedPaths = decoded }
        }
        
        // 加载历史记录
        if let data = try? Data(contentsOf: historyURL), 
           let decoded = try? JSONDecoder().decode([JumpRecord].self, from: data) {
            await MainActor.run { self.jumpHistory = decoded }
        }
        
        // 加载完整的路径列表
        var loadedItems: [PathItem] = []
        if let data = try? Data(contentsOf: fileURL), 
           let decoded = try? JSONDecoder().decode([PathItem].self, from: data) {
            var mergedMap: [String: PathItem] = [:]
            for item in decoded {
                var normalized = item.path
                if normalized.hasSuffix("/") && normalized.count > 1 { normalized.removeLast() }
                
                if let existing = mergedMap[normalized] {
                    mergedMap[normalized]!.visitCount = max(existing.visitCount, item.visitCount)
                    if item.lastVisitedAt > existing.lastVisitedAt {
                        mergedMap[normalized]!.lastVisitedAt = item.lastVisitedAt
                    }
                    if item.isFavorite { mergedMap[normalized]!.isFavorite = true }
                } else {
                    mergedMap[normalized] = item
                }
            }
            loadedItems = Array(mergedMap.values)
        }
        
        // 合并 autojump 数据
        let autojumpItems = await parseAutojump()
        for item in autojumpItems {
            var normalized = item.path
            if normalized.hasSuffix("/") && normalized.count > 1 { normalized.removeLast() }
            
            if let index = loadedItems.firstIndex(where: { 
                var p = $0.path
                if p.hasSuffix("/") && p.count > 1 { p.removeLast() }
                return p == normalized 
            }) {
                if item.visitCount > loadedItems[index].visitCount { 
                    loadedItems[index].visitCount = item.visitCount 
                }
            } else { 
                loadedItems.append(item) 
            }
        }
        
        // 更新到主线程
        await MainActor.run { 
            self.items = loadedItems
            self.recalculateScores()
        }
    }
    
    func recalculateScores() {

        // 触发 UI 更新：排序
        self.items.sort { $0.score > $1.score }
    }
    
    private func saveScoringWeights() {
        if let encoded = try? JSONEncoder().encode(customPathWeights) { try? encoded.write(to: scoringWeightsURL) }
    }
    
    func resetRulesToDefaults() {
        self.contextRules = ContextRule.defaults
        saveRules()
        FolderAnalyzer.shared.clearCache()
    }
    
    func savePredictorRules() {
        if let encoded = try? JSONEncoder().encode(predictorRules) { try? encoded.write(to: predictorRulesURL) }
        FolderAnalyzer.shared.clearCache()
    }
    
    func saveTechRules() {
        if let encoded = try? JSONEncoder().encode(techDetectionRules) { try? encoded.write(to: techRulesURL) }
        FolderAnalyzer.shared.clearCache()
        
        // 修改即生效：立即重置并刷新内存中的项目信息
        DispatchQueue.main.async {
            for i in 0..<self.items.count {
                self.refreshMetadata(for: self.items[i].id)
            }
        }
    }
    
    func resetTechRules() {
        self.techDetectionRules = TechDetectionRule.defaults
        saveTechRules()
    }
    
    func resetPredictorRules() {
        self.predictorRules = ContextPredictor.defaultRules
        savePredictorRules()
    }
    
    func getEditorDisplayName() -> String {
        let presets = ["com.microsoft.VSCode": "Visual Studio Code", "com.todesktop.230313mzl4w4u92": "Cursor", "com.sublimetext.4": "Sublime Text", "dev.zed.Zed": "Zed", "com.jetbrains.intellij": "IntelliJ IDEA", "com.apple.TextEdit": "TextEdit"]
        return presets[preferredEditor] ?? (customEditorName.isEmpty ? preferredEditor : customEditorName)
    }
    
    func getTerminalDisplayName() -> String {
        let presets = ["com.googlecode.iterm2": "iTerm2", "dev.warp.Warp-Stable": "Warp", "com.apple.Terminal": "Terminal", "com.github.wez.wezterm": "WezTerm"]
        return presets[preferredTerminal] ?? (customTerminalName.isEmpty ? preferredTerminal : customTerminalName)
    }
    
    var todaySavedSeconds: Int {
        let calendar = Calendar.current
        let todayRecords = jumpHistory.filter { calendar.isDateInToday($0.timestamp) }
        return todayRecords.reduce(0) { sum, record in
            var weight = 10
            if record.actionType == "Inject" { weight = 30 }
            else if record.actionType.hasPrefix("Rule:") { weight = 20 }
            else if record.actionType == "Open in Editor" || record.actionType == "Open in Terminal" { weight = 15 }
            return sum + weight
        }
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
    
    func recordJump(path: String, actionType: String) {
        var normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedPath.hasSuffix("/") && normalizedPath.count > 1 {
            normalizedPath.removeLast()
        }
        
        DispatchQueue.main.async {
            // 去重逻辑：如果最后一条记录路径相同且在 5 分钟内，则只更新时间
            if let lastIndex = self.jumpHistory.indices.last,
               self.jumpHistory[lastIndex].path == normalizedPath,
               abs(self.jumpHistory[lastIndex].timestamp.timeIntervalSinceNow) < 300 {
                self.jumpHistory[lastIndex].timestamp = Date()
            } else {
                let record = JumpRecord(path: normalizedPath, timestamp: Date(), actionType: actionType)
                self.jumpHistory.append(record)
                if self.jumpHistory.count > 500 { self.jumpHistory.removeFirst() }
            }
            self.saveHistory()
        }
    }
    
    func addOrUpdate(path: String, source: PathItem.SourceType) {
        var cp = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if cp.hasSuffix("/") && cp.count > 1 {
            cp.removeLast()
        }
        
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
            self.recalculateScores(); self.save(); self.refreshMetadata(for: id)
        }
    }
    
    func refreshMetadata(for id: UUID, priority: TaskPriority = .background) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let path = items[index].path
        Task(priority: priority) {
            let result = await FolderAnalyzer.shared.analyze(path: path)
            await MainActor.run {
                if let idx = self.items.firstIndex(where: { $0.id == id }) {
                    self.objectWillChange.send() // 强制通知订阅者
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
            items[index].isFavorite.toggle(); self.recalculateScores(); save()
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
    
    // MARK: - Export / Import
    
    private struct ExportPayload: Codable {
        var excludedPaths: Set<String>?
        var contextRules: [ContextRule]?
        var predictorRules: [AppContextRule]?
        var techDetectionRules: [TechDetectionRule]?
        var enabledToolbarActions: [StandardAction]?
        var showResultTags: Bool?
        var showResultScore: Bool?
        var showResultInfo: Bool?
        var preferredEditor: String?
        var preferredTerminal: String?
        
        // Scoring
        var weightFrequency: Double?
        var weightRecency: Double?
        var weightPrediction: Double?
        var customPathWeights: [String: Double]?
    }
    
    func exportSettings() -> URL? {
        var payload = ExportPayload()
        
        if !excludedPaths.isEmpty { payload.excludedPaths = excludedPaths }
        if contextRules != ContextRule.defaults { payload.contextRules = contextRules }
        if predictorRules != ContextPredictor.defaultRules { payload.predictorRules = predictorRules }
        if techDetectionRules != TechDetectionRule.defaults { payload.techDetectionRules = techDetectionRules }
        if enabledToolbarActions != StandardAction.allCases { payload.enabledToolbarActions = enabledToolbarActions }
        
        if showResultTags == false { payload.showResultTags = false }
        if showResultScore == false { payload.showResultScore = false }
        if showResultInfo == false { payload.showResultInfo = false }
        
        let defaultEditor = "com.microsoft.VSCode"
        let defaultTerminal = "dev.warp.Warp-Stable"
        if preferredEditor != defaultEditor { payload.preferredEditor = preferredEditor }
        if preferredTerminal != defaultTerminal { payload.preferredTerminal = preferredTerminal }
        
        if weightFrequency != 1.0 { payload.weightFrequency = weightFrequency }
        if weightRecency != 1.0 { payload.weightRecency = weightRecency }
        if weightPrediction != 1.0 { payload.weightPrediction = weightPrediction }
        if !customPathWeights.isEmpty { payload.customPathWeights = customPathWeights }
        
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("WayPoint_Settings.json")
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }
    
    func importSettings(from url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(ExportPayload.self, from: data) else {
            return false
        }
        
        DispatchQueue.main.async {
            if let excluded = payload.excludedPaths {
                self.excludedPaths.formUnion(excluded)
                self.save()
            }
            if let rules = payload.contextRules {
                self.contextRules = rules
                self.saveRules()
            }
            if let predictors = payload.predictorRules {
                self.predictorRules = predictors
                self.savePredictorRules()
            }
            if let techs = payload.techDetectionRules {
                self.techDetectionRules = techs
                self.saveTechRules()
            }
            if let actions = payload.enabledToolbarActions {
                self.enabledToolbarActions = actions // Property observer handles saving
            }
            if let tags = payload.showResultTags { self.showResultTags = tags }
            if let score = payload.showResultScore { self.showResultScore = score }
            if let info = payload.showResultInfo { self.showResultInfo = info }
            if let editor = payload.preferredEditor { self.preferredEditor = editor }
            if let term = payload.preferredTerminal { self.preferredTerminal = term }
            
            // Scoring
            if let wFreq = payload.weightFrequency { self.weightFrequency = wFreq }
            if let wRec = payload.weightRecency { self.weightRecency = wRec }
            if let wPred = payload.weightPrediction { self.weightPrediction = wPred }
            if let wPaths = payload.customPathWeights { self.customPathWeights = wPaths }
        }
        return true
    }
}
