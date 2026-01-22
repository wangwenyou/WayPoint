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
        let sm = StorageManager.shared
        let timeInterval = Date().timeIntervalSince(lastVisitedAt)
        
        // 1. Recency: weightRecency > 1 加速衰减 (更看重近期)，< 1 减缓衰减 (更看重长期)
        // 默认半衰期约 7 天
        let halfLife = (3600 * 24 * 7) / max(0.1, sm.weightRecency)
        let decay = exp(-timeInterval / halfLife)
        
        // 2. Frequency
        var finalScore = (Double(visitCount) * sm.weightFrequency) * decay
        
        // 3. Favorites (Fixed Bonus)
        if isFavorite { finalScore += 1000 }
        
        // 4. Context Prediction
        // 注意：这里访问 ContextPredictor 单例，确保其计算开销低
        let bonus = ContextPredictor.shared.calculateBonus(for: self)
        finalScore += Double(bonus) * sm.weightPrediction
        
        // 5. Custom Path Weights (Multiplier)
        // 简单的路径前缀匹配
        for (prefix, multiplier) in sm.customPathWeights {
            if path.hasPrefix(prefix) {
                finalScore *= multiplier
            }
        }
        
        return finalScore
    }
}