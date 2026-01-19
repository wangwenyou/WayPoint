import Foundation
import Combine  // 必须引入 Combine 才能使用 @Published 和 ObservableObject

class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    @Published var items: [PathItem] = []
    @Published var excludedPaths: Set<String> = [] // 黑名单
    
    private let fileURL: URL
    private let excludeURL: URL // 黑名单存储路径
    
    private init() {
        // 数据保存在 Application Support 目录
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appDir = urls[0].appendingPathComponent("WayPoint")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        
        self.fileURL = appDir.appendingPathComponent("waypoints.json")
        self.excludeURL = appDir.appendingPathComponent("excluded_paths.json")
        
        load()
        importAutojump()
    }
    
    // 从 autojump 导入历史数据
    func importAutojump() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let potentialURLs = [
            home.appendingPathComponent(".local/share/autojump/autojump.txt"),
            home.appendingPathComponent("Library/autojump/autojump.txt")
        ]
        
        var didAnyUpdate = false
        
        for autojumpURL in potentialURLs {
            guard FileManager.default.fileExists(atPath: autojumpURL.path) else { continue }
            print("importAutojump: Found database at \(autojumpURL.path)")
            
            do {
                let content = try String(contentsOf: autojumpURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                
                for line in lines where !line.isEmpty {
                    let parts = line.components(separatedBy: "\t")
                    guard parts.count >= 2, let weight = Double(parts[0]) else { continue }
                    let path = parts[1]
                    
                    // 标准化路径
                    let cleanPath = standardize(path)
                    
                    // 检查黑名单
                    if excludedPaths.contains(cleanPath) { continue }
                    
                    // 检查是否已存在
                    if let index = items.firstIndex(where: { standardize($0.path) == cleanPath }) {
                        // 如果从 autojump 读到的权重更大，则更新
                        if Double(items[index].visitCount) < weight {
                            items[index].visitCount = Int(weight)
                            didAnyUpdate = true
                        }
                    } else {
                        // 目录真实性校验
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: cleanPath, isDirectory: &isDir), isDir.boolValue {
                            let folderName = (cleanPath as NSString).lastPathComponent
                            let newItem = PathItem(path: cleanPath, alias: folderName, visitCount: Int(weight), source: .manual)
                            items.append(newItem)
                            didAnyUpdate = true
                        }
                    }
                }
            } catch {
                print("⚠️ Autojump import failed for \(autojumpURL.path): \(error)")
            }
        }
        
        if didAnyUpdate {
            items.sort { $0.score > $1.score }
            save()
        }
    }
    
    func load() {
        // 加载记录
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([PathItem].self, from: data) {
            
            // 数据迁移与合并：标准化路径并合并重复项
            var mergedItems: [String: PathItem] = [:]
            for item in decoded {
                let sPath = standardize(item.path)
                if var existing = mergedItems[sPath] {
                    // 合并访问次数和状态
                    existing.visitCount += item.visitCount
                    if item.lastVisitedAt > existing.lastVisitedAt {
                        existing.lastVisitedAt = item.lastVisitedAt
                    }
                    if item.isFavorite { existing.isFavorite = true }
                    mergedItems[sPath] = existing
                } else {
                    // 创建标准化的副本
                    let standardizedItem = PathItem(
                        id: item.id, 
                        path: sPath, 
                        alias: item.alias, 
                        visitCount: item.visitCount, 
                        lastVisitedAt: item.lastVisitedAt, 
                        isFavorite: item.isFavorite, 
                        source: item.source
                    )
                    mergedItems[sPath] = standardizedItem
                }
            }
            self.items = Array(mergedItems.values).sorted { $0.score > $1.score }
        }
        
        // 加载黑名单
        if let data = try? Data(contentsOf: excludeURL),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.excludedPaths = decoded
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(items) {
            try? encoded.write(to: fileURL)
        }
        
        if let encoded = try? JSONEncoder().encode(excludedPaths) {
            try? encoded.write(to: excludeURL)
        }
    }
    
    private func standardize(_ path: String) -> String {
        var cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        // 移除末尾斜杠 (如 /Users/ -> /Users)，但保留根路径 /
        while cleanPath.count > 1 && cleanPath.hasSuffix("/") {
            cleanPath.removeLast()
        }
        return cleanPath
    }
    
    // 添加或更新路径
    func addOrUpdate(path: String, source: PathItem.SourceType) {
        let cleanPath = standardize(path)
        
        // 0. 检查黑名单
        if excludedPaths.contains(cleanPath) {
            return
        }
        
        // 1. 简单校验：必须是存在的文件夹
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: cleanPath, isDirectory: &isDir), isDir.boolValue else {
            return
        }
        
        let folderName = (cleanPath as NSString).lastPathComponent
        
        // 在主线程更新 UI 相关的数据
        DispatchQueue.main.async {
            if let index = self.items.firstIndex(where: { self.standardize($0.path) == cleanPath }) {
                // 已存在：更新权重
                self.items[index].visitCount += 1
                self.items[index].lastVisitedAt = Date()
            } else {
                // 新增
                let newItem = PathItem(path: cleanPath, alias: folderName, source: source)
                self.items.append(newItem)
            }
            
            // 重新排序：收藏 > 分数高 > 分数低
            self.items.sort { $0.score > $1.score }
            self.save()
        }
    }
    
    // 排除某个路径
    func exclude(path: String) {
        let cleanPath = standardize(path)
        DispatchQueue.main.async {
            // 1. 加入黑名单
            self.excludedPaths.insert(cleanPath)
            
            // 2. 从现有列表中移除
            self.items.removeAll(where: { self.standardize($0.path) == cleanPath })
            
            self.save()
            print("🚫 已排除路径: \(cleanPath)")
        }
    }
    
    // 取消排除（恢复）
    func unexclude(path: String) {
        let cleanPath = standardize(path)
        DispatchQueue.main.async {
            self.excludedPaths.remove(cleanPath)
            self.save()
            print("✅ 已恢复路径: \(cleanPath)")
        }
    }
    
    func toggleFavorite(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isFavorite.toggle()
            items.sort { $0.score > $1.score }
            save()
        }
    }
}
