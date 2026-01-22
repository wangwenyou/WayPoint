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
        let rules = StorageManager.shared.predictorRules.filter { $0.isEnabled }
        
        // 1. 基于当前激活应用的预测
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleId = frontApp.bundleIdentifier {
            
            for rule in rules {
                if bundleId == rule.bundleId {
                    // 只要文件夹的标签命中该应用关联的任一标签，即加分
                    let hasMatch = item.technology != nil && rule.targetTags.contains(item.technology!) ||
                                   item.tags.contains { rule.targetTags.contains($0) }
                    
                    if hasMatch {
                        totalBonus += rule.boost
                    }
                }
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
