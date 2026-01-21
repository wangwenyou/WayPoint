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
        if let cached = queue.sync(execute: { cache[path] }) { return cached }
        
        let url = URL(fileURLWithPath: path)
        var tags: [String] = []
        var tech: String? = nil
        var status: String? = nil
        var actions: [ContextAction] = []
        
        let fileManager = FileManager.default
        let rules = StorageManager.shared.contextRules.filter { $0.isEnabled }
        
        // 1. Git (人格基础分析，仅保留状态和 Tags 检测)
        let gitURL = url.appendingPathComponent(".git")
        if fileManager.fileExists(atPath: gitURL.path) {
            tags.append("Code")
            status = getGitStatus(path: path)
        }
        
        // 2. 执行所有配置好的动态规则
        for rule in rules {
            let triggerPath = url.appendingPathComponent(rule.triggerFile).path
            var matched = false
            
            if rule.triggerFile.contains("*") {
                matched = matchesWildcard(path: path, pattern: rule.triggerFile)
            } else {
                matched = fileManager.fileExists(atPath: triggerPath)
            }
            
            if matched {
                // 如果是 URL 类型，我们需要执行命令获取输出，或者直接处理特殊逻辑
                if rule.actionType == .url {
                    if rule.name == "Open Repo" { // 匹配新名称
                        if let resolvedUrl = getGitRemote(path: path) {
                            actions.append(ContextAction(type: .gitRemote, title: rule.name, icon: rule.actionIcon, command: resolvedUrl))
                        }
                    } else {
                        // 通用 URL 动作：执行命令，取输出作为 URL
                        if let output = runCommand("/bin/bash", args: ["-c", "cd \(path) && \(rule.command)"]) {
                            actions.append(ContextAction(type: .gitRemote, title: rule.name, icon: rule.actionIcon, command: output.trimmingCharacters(in: .whitespacesAndNewlines)))
                        }
                    }
                } else {
                    // 终端命令类型
                    actions.append(ContextAction(type: .shellCommand, title: rule.name, icon: rule.actionIcon, command: rule.command))
                }
            }
        }
        
        // 3. 通用技术栈识别 (用于 Tag 显示)
        if fileManager.fileExists(atPath: url.appendingPathComponent("package.json").path) { tech = "Node.js" }
        
        if status == nil {
            if let attr = try? fileManager.attributesOfItem(atPath: path),
               let modDate = attr[.modificationDate] as? Date {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                status = String(format: NSLocalizedString("Modified %@", comment: ""), formatter.localizedString(for: modDate, relativeTo: Date()))
            }
        }
        
        let result = AnalysisResult(tags: Array(Set(tags)), technology: tech, statusSummary: status, actions: actions)
        queue.async(flags: .barrier) { self.cache[path] = result }
        return result
    }
    
    private func matchesWildcard(path: String, pattern: String) -> Bool {
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
        let pipe = Pipe(); process.standardOutput = pipe; process.standardError = Pipe()
        do {
            try process.run(); process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)
            return output?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? output : nil
        } catch { return nil }
    }
}