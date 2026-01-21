import Foundation

struct FuzzyMatcher {
    /// 计算匹配分数
    /// - Returns: 分数 (0-100)，0 表示不匹配。分数越高匹配度越高。
    static func score(query: String, text: String) -> Int {
        if query.isEmpty { return 1 }
        
        let q = query.localizedLowercase
        let t = text.localizedLowercase
        
        // 1. 精确匹配 (最高分)
        if t == q { return 100 }
        
        // 2. 前缀匹配
        if t.hasPrefix(q) { return 90 }
        
        // 3. 单词边界匹配 (例如 "VS Code" 匹配 "vc")
        // 简易实现：检查是否包含 query
        if t.contains(q) { return 60 }
        
        // 4. 模糊顺序匹配 (Subsequence)
        let generatedArray = Array(t)
        let queryArray = Array(q)
        
        var queryIndex = 0
        var textIndex = 0
        var matchCount = 0
        
        while queryIndex < queryArray.count && textIndex < generatedArray.count {
            if queryArray[queryIndex] == generatedArray[textIndex] {
                queryIndex += 1
                matchCount += 1
            }
            textIndex += 1
        }
        
        if queryIndex == queryArray.count {
            // 基础分 10，根据长度比例微调
            // 越短的 text 匹配了相同的 query，分数应该越高
            let density = Double(query.count) / Double(text.count)
            return 10 + Int(density * 20)
        }
        
        return 0
    }
}