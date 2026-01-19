import Foundation

struct PathItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let path: String
    var alias: String // 文件夹名称，用于显示
    var visitCount: Int = 1
    var lastVisitedAt: Date = Date()
    var isFavorite: Bool = false
    var source: SourceType
    
    enum SourceType: String, Codable {
        case clipboard
        case finderHistory
        case manual
    }
    
    // 计算权重分数 (核心算法)
    var score: Double {
        if isFavorite { return 1_000_000 } // 收藏永远置顶
        
        let timeFactor = -lastVisitedAt.timeIntervalSinceNow // 距离现在的秒数
        // 简单算法：次数 * 100 - (距离现在的小时数)
        // 意味着：最近 1 小时访问 1 次，优于 100 小时前访问 1 次
        return Double(visitCount * 1000) - (timeFactor / 3600.0)
    }
    
    // 用于去重
    static func == (lhs: PathItem, rhs: PathItem) -> Bool {
        return lhs.path == rhs.path
    }
}
