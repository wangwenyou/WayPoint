import Foundation

struct FuzzyMatcher {
    /// 简单模糊匹配：检查 query 的字符是否按顺序出现在 text 中
    /// 例如 query: "dl", text: "Downloads" -> True
    static func match(query: String, text: String) -> Bool {
        if query.isEmpty { return true }
        
        let generatedArray = Array(text.localizedLowercase)
        let queryArray = Array(query.localizedLowercase)
        
        var queryIndex = 0
        var textIndex = 0
        
        while queryIndex < queryArray.count && textIndex < generatedArray.count {
            if queryArray[queryIndex] == generatedArray[textIndex] {
                queryIndex += 1
            }
            textIndex += 1
        }
        
        return queryIndex == queryArray.count
    }
}
