import Foundation

enum ContextActionType: String, Codable {
    case gitRemote
    case shellCommand
}

struct ContextAction: Codable, Hashable {
    let type: ContextActionType
    let title: String
    let icon: String
    let command: String? 
}

class FolderAnalyzer {
    static let shared = FolderAnalyzer()
    
    private var cache: [String: AnalysisResult] = [: ]
    private let queue = DispatchQueue(label: "com.waypoint.analyzer", attributes: .concurrent)
    
    struct AnalysisResult {
        let tags: [String]
        let technology: String?
        let statusSummary: String?
        let actions: [ContextAction]
    }
    
    func clearCache() {
        queue.sync(flags: .barrier) {
            self.cache.removeAll()
        }
    }
    
    func analyze(path: String) async -> AnalysisResult {
        var normalizedPath = path
        if normalizedPath.hasSuffix("/") && normalizedPath.count > 1 {
            normalizedPath.removeLast()
        }
        
        if let cached = queue.sync(execute: { cache[normalizedPath] }) { return cached }
        
        let url = URL(fileURLWithPath: normalizedPath)
        var tags: [String] = []
        var tech: String? = nil
        var status: String? = nil
        var actions: [ContextAction] = []
        
        let fileManager = FileManager.default
        let storage = StorageManager.shared
        
        // 1. 基础标签分析 (Git)
        let gitURL = url.appendingPathComponent(".git")
        if fileManager.fileExists(atPath: gitURL.path) {
            tags.append("Code")
        }
        
        // 2. 动态标签检测 + 人格脚本提取 (核心优先级：人格 > 系统)
        // 确保在这里只执行一个最高优先级的脚本
        let techRules = storage.techDetectionRules.filter { $0.isEnabled }
        var scriptExecuted = false
        
        for rule in techRules {
            if matchesAnyWildcard(path: normalizedPath, patterns: rule.triggerFiles) {
                tech = rule.name
                tags.append(rule.name)
                tags.append("Code")
                
                // 只有当全局 showVersionNumber 开启且有人格脚本时才执行
                if StorageManager.shared.showVersionNumber, !scriptExecuted, let script = rule.statusScript, !script.isEmpty {
                    let comprehensivePath = "export PATH='/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH'"
                    let envScript = "\(comprehensivePath); cd '\(normalizedPath)' && \(script)"
                    
                    if let output = runCommand("/bin/zsh", args: ["-c", envScript]) {
                        status = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        scriptExecuted = true // 标记已执行，防止重复
                    }
                }
            }
        }
        
        // 3. 补充系统状态 (仅当人格脚本没有输出时)
        if status == nil || status?.isEmpty == true {
            if fileManager.fileExists(atPath: gitURL.path) {
                status = getGitStatus(path: normalizedPath)
            } else if let attr = try? fileManager.attributesOfItem(atPath: normalizedPath),
                      let modDate = attr[.modificationDate] as? Date {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                status = String(format: NSLocalizedString("Modified %@", comment: ""), formatter.localizedString(for: modDate, relativeTo: Date()))
            }
        }
        
        // 4. 处理上下文动作
        let actionRules = storage.contextRules.filter { $0.isEnabled }
        for rule in actionRules {
            if matchesAnyWildcard(path: normalizedPath, patterns: rule.triggerFile) {
                if rule.actionType == .url {
                    if rule.name == "Open Repo" { 
                        if let resolvedUrl = getGitRemote(path: normalizedPath) {
                            actions.append(ContextAction(type: .gitRemote, title: rule.name, icon: rule.actionIcon, command: resolvedUrl))
                        }
                    } else {
                        if let output = runCommand("/bin/zsh", args: ["-c", "cd '\(normalizedPath)' && \(rule.command)"]) {
                            actions.append(ContextAction(type: .gitRemote, title: rule.name, icon: rule.actionIcon, command: output.trimmingCharacters(in: .whitespacesAndNewlines)))
                        }
                    }
                } else {
                    actions.append(ContextAction(type: .shellCommand, title: rule.name, icon: rule.actionIcon, command: rule.command))
                }
            }
        }
        
        let result = AnalysisResult(tags: Array(Set(tags)), technology: tech, statusSummary: status, actions: actions)
        // 缓存中记录是否为系统信息，UI 渲染时参考
        queue.async(flags: .barrier) { self.cache[normalizedPath] = result }
        return result
    }
    
    // 支持逗号分隔的多模式匹配 (OR 逻辑)
    private func matchesAnyWildcard(path: String, patterns: String) -> Bool {
        let patternList = patterns.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for pattern in patternList {
            if matchesSingleWildcard(path: path, pattern: pattern) { return true }
        }
        return false
    }
    
    private func matchesSingleWildcard(path: String, pattern: String) -> Bool {
        // 如果包含路径分隔符，则进行完整路径拼接检查
        if pattern.contains("/") {
            let fullPath = (path as NSString).appendingPathComponent(pattern)
            return FileManager.default.fileExists(atPath: fullPath)
        }
        
        // 否则在当前目录下进行通配符搜索
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: path) else { return false }
        let regexPattern = pattern.replacingOccurrences(of: ".", with: "\\.").replacingOccurrences(of: "*", with: ".*")
        guard let regex = try? NSRegularExpression(pattern: "^\(regexPattern)$", options: .caseInsensitive) else { return false }
        return files.contains { regex.firstMatch(in: $0, options: [], range: NSRange(location: 0, length: $0.utf16.count)) != nil }
    }
    
    private func getGitStatus(path: String) -> String? {
        guard let output = runCommand("/usr/bin/git", args: ["-C", path, "status", "--porcelain"]) else { return nil }
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.count > 0 ? String(format: NSLocalizedString("%lld files changed (Git)", comment: ""), lines.count) : NSLocalizedString("Clean (Git)", comment: "")
    }
    
    private func getGitRemote(path: String) -> String? {
        guard let output = runCommand("/usr/bin/git", args: ["-C", path, "remote", "get-url", "origin"]) else { return nil }
        var url = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasPrefix("git@") {
            url = url.replacingOccurrences(of: ":", with: "/").replacingOccurrences(of: "git@", with: "https://")
        }
        if url.hasSuffix(".git") { url = String(url.dropLast(4)) }
        return url.isEmpty ? nil : url
    }
    
    private func runCommand(_ executable: String, args: [String]) -> String? {
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = args
        let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe // 合并输出流
        do {
            try process.run(); process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)
            return output?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? output : nil
        } catch { return nil }
    }
}