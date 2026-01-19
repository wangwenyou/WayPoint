import Foundation
import Combine

struct JumpRecord: Codable {
    let path: String
    let timestamp: Date
}

class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    @Published var items: [PathItem] = []
    @Published var excludedPaths: Set<String> = []
    @Published var jumpHistory: [JumpRecord] = [] // 记录跳转历史
    
    private let fileURL: URL
    private let excludeURL: URL
    private let historyURL: URL // 跳转历史存储路径
    
    private init() {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appDir = urls[0].appendingPathComponent("WayPoint")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        
        self.fileURL = appDir.appendingPathComponent("waypoints.json")
        self.excludeURL = appDir.appendingPathComponent("excluded_paths.json")
        self.historyURL = appDir.appendingPathComponent("jump_history.json")
        
        load()
        importAutojump()
    }
    
    // 记录一次成功的跳转
    func recordJump(path: String) {
        let record = JumpRecord(path: path, timestamp: Date())
        DispatchQueue.main.async {
            self.jumpHistory.append(record)
            // 只保留最近 1000 条记录，避免文件过大
            if self.jumpHistory.count > 1000 {
                self.jumpHistory.removeFirst(self.jumpHistory.count - 1000)
            }
            self.saveHistory()
        }
    }
    
    func importAutojump() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let potentialURLs = [
            home.appendingPathComponent(".local/share/autojump/autojump.txt"),
            home.appendingPathComponent("Library/autojump/autojump.txt")
        ]
        
        var didAnyUpdate = false
        for autojumpURL in potentialURLs {
            guard FileManager.default.fileExists(atPath: autojumpURL.path) else { continue }
            do {
                let content = try String(contentsOf: autojumpURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                for line in lines where !line.isEmpty {
                    let parts = line.components(separatedBy: "\t")
                    guard parts.count >= 2, let weight = Double(parts[0]) else { continue }
                    let path = parts[1]
                    let cleanPath = standardize(path)
                    if excludedPaths.contains(cleanPath) { continue }
                    
                    if let index = items.firstIndex(where: { standardize($0.path) == cleanPath }) {
                        if Double(items[index].visitCount) < weight {
                            items[index].visitCount = Int(weight)
                            didAnyUpdate = true
                        }
                    } else {
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: cleanPath, isDirectory: &isDir), isDir.boolValue {
                            let folderName = (cleanPath as NSString).lastPathComponent
                            let newItem = PathItem(path: cleanPath, alias: folderName, visitCount: Int(weight), source: .manual)
                            items.append(newItem)
                            didAnyUpdate = true
                        }
                    }
                }
            } catch { print("⚠️ Autojump import failed: \(error)") }
        }
        if didAnyUpdate {
            items.sort { $0.score > $1.score }
            save()
        }
    }
    
    func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([PathItem].self, from: data) {
            self.items = decoded.sorted { $0.score > $1.score }
        }
        if let data = try? Data(contentsOf: excludeURL),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.excludedPaths = decoded
        }
        if let data = try? Data(contentsOf: historyURL),
           let decoded = try? JSONDecoder().decode([JumpRecord].self, from: data) {
            self.jumpHistory = decoded
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
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(jumpHistory) {
            try? encoded.write(to: historyURL)
        }
    }
    
    private func standardize(_ path: String) -> String {
        var cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleanPath.count > 1 && cleanPath.hasSuffix("/") { cleanPath.removeLast() }
        return cleanPath
    }
    
    func addOrUpdate(path: String, source: PathItem.SourceType) {
        let cleanPath = standardize(path)
        if excludedPaths.contains(cleanPath) { return }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: cleanPath, isDirectory: &isDir), isDir.boolValue else { return }
        
        let folderName = (cleanPath as NSString).lastPathComponent
        DispatchQueue.main.async {
            if let index = self.items.firstIndex(where: { self.standardize($0.path) == cleanPath }) {
                self.items[index].visitCount += 1
                self.items[index].lastVisitedAt = Date()
            } else {
                let newItem = PathItem(path: cleanPath, alias: folderName, source: source)
                self.items.append(newItem)
            }
            self.items.sort { $0.score > $1.score }
            self.save()
        }
    }
    
    func exclude(path: String) {
        let cleanPath = standardize(path)
        DispatchQueue.main.async {
            self.excludedPaths.insert(cleanPath)
            self.items.removeAll(where: { self.standardize($0.path) == cleanPath })
            self.save()
        }
    }
    
    func unexclude(path: String) {
        let cleanPath = standardize(path)
        DispatchQueue.main.async {
            self.excludedPaths.remove(cleanPath)
            self.save()
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