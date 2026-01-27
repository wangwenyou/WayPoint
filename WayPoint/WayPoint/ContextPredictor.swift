import AppKit
import SwiftUI

struct AppContextRule: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var bundleId: String
    var targetTags: [String] // 修改为数组以支持多选
    var boost: Int
    var isEnabled: Bool = true
}

class ContextPredictor {
    static let shared = ContextPredictor()
    
    // 性能优化：缓存当前应用的规则
    private var cachedBundleId: String?
    private var cachedRules: [AppContextRule] = []
    private var lastUpdate: Date = .distantPast
    
    static let defaultRules: [AppContextRule] = [
        AppContextRule(bundleId: "com.apple.dt.Xcode", targetTags: ["Code", "Swift"], boost: 500),
        AppContextRule(bundleId: "com.microsoft.VSCode", targetTags: ["Code", "Python", "Java", "Rust", "Go"], boost: 500),
        AppContextRule(bundleId: "com.jetbrains.intellij", targetTags: ["Code", "Java", "Kotlin"], boost: 500),
        AppContextRule(bundleId: "dev.zed.Zed", targetTags: ["Code", "Rust"], boost: 500),
        AppContextRule(bundleId: "com.googlecode.iterm2", targetTags: ["Code", "Python", "Rust"], boost: 300),
        AppContextRule(bundleId: "com.adobe.Photoshop", targetTags: ["Design"], boost: 500),
        AppContextRule(bundleId: "com.figma.Desktop", targetTags: ["Design"], boost: 500)
    ]
    
    func calculateBonus(for item: PathItem) -> Int {
        var totalBonus = 0
        
        // 1. 基于当前激活应用的预测 (带缓存优化)
        let now = Date()
        if now.timeIntervalSince(lastUpdate) > 1.0 {
            // 每秒最多更新一次缓存
            if let frontApp = NSWorkspace.shared.frontmostApplication,
               let bundleId = frontApp.bundleIdentifier {
                cachedBundleId = bundleId
                cachedRules = StorageManager.shared.predictorRules.filter { 
                    $0.isEnabled && $0.bundleId == bundleId 
                }
            } else {
                cachedBundleId = nil
                cachedRules = []
            }
            lastUpdate = now
        }
        
        // 使用缓存的规则进行匹配
        for rule in cachedRules {
            let hasMatch = item.technology != nil && rule.targetTags.contains(item.technology!) ||
                           item.tags.contains { rule.targetTags.contains($0) }
            
            if hasMatch {
                totalBonus += rule.boost
            }
        }
        
        // 2. 基于时间的预测 (例如早晨提权)
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 8 && hour <= 10 {
            if item.visitCount > 10 { totalBonus += 200 }
        }
        
        return totalBonus
    }
}
