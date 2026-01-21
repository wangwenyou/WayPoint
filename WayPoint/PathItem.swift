import Foundation

struct PathItem: Identifiable, Codable, Equatable {
    let id: UUID
    let path: String
    var alias: String
    var visitCount: Int
    var lastVisitedAt: Date
    var isFavorite: Bool
    let source: SourceType
    
    // --- 新增：人格属性 ---
    var tags: [String] = []          // 如 ["Code", "Design", "Project"]
    var technology: String? = nil    // 如 "Node.js v18.1.0", "Swift", "Python"
    var statusSummary: String? = nil // 如 "5 files changed (Git)", "Modified 2m ago"
    var actions: [ContextAction] = [] // 智能上下文动作
    
    enum SourceType: String, Codable {
        case manual, finderHistory, clipboard
    }
    
    init(id: UUID = UUID(), path: String, alias: String, visitCount: Int = 1, lastVisitedAt: Date = Date(), isFavorite: Bool = false, source: SourceType) {
        self.id = id
        self.path = path
        self.alias = alias
        self.visitCount = visitCount
        self.lastVisitedAt = lastVisitedAt
        self.isFavorite = isFavorite
        self.source = source
    }
    
    var score: Double {
        let timeInterval = Date().timeIntervalSince(lastVisitedAt)
        let decay = exp(-timeInterval / (3600 * 24 * 7)) // 7天衰减
        let baseScore = Double(visitCount) * decay
        return isFavorite ? baseScore + 1000 : baseScore
    }
}