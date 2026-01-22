import Foundation

// 新增：技术栈/标签检测规则
struct TechDetectionRule: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String        // 标签名称，如 "Java"
    var triggerFiles: String // 触发文件，逗号分隔支持“或”逻辑，如 "pom.xml, build.gradle"
    var color: String = "blue"
    var statusScript: String? = nil 
    var isEnabled: Bool = true
    var isDefault: Bool = false
    
    static let defaults: [TechDetectionRule] = [
        TechDetectionRule(name: "Node.js", triggerFiles: "package.json", statusScript: "node -v", isDefault: true),
        TechDetectionRule(name: "Python", triggerFiles: "requirements.txt, Pipfile, pyproject.toml, *.py", statusScript: "python3 --version 2>&1 | awk '{print $2}'", isDefault: true),
        TechDetectionRule(name: "Java", triggerFiles: "pom.xml, build.gradle, src/main/java", statusScript: "java -version 2>&1 | head -n 1 | awk -F '\"' '{print $2}'", isDefault: true),
        TechDetectionRule(name: "Swift", triggerFiles: "*.xcodeproj, Package.swift", statusScript: "swift --version | head -n 1 | awk '{print $4}'", isDefault: true),
        TechDetectionRule(name: "Rust", triggerFiles: "Cargo.toml", statusScript: "rustc --version | awk '{print $2}'", isDefault: true),
        TechDetectionRule(name: "Go", triggerFiles: "go.mod", statusScript: "go version | awk '{print $3}'", isDefault: true),
        TechDetectionRule(name: "Design", triggerFiles: "*.psd, *.fig, *.sketch", isDefault: true)
    ]
}

enum RuleActionType: String, Codable, CaseIterable {
    case terminal = "Terminal Command"
    case url = "Open URL"
    
    var displayName: String {
        switch self {
        case .terminal: return NSLocalizedString("Run in Terminal", comment: "")
        case .url: return NSLocalizedString("Open URL", comment: "")
        }
    }
}

struct ContextRule: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var triggerFile: String // 现在支持逗号分隔，如 "package.json, yarn.lock"
    var actionIcon: String
    var actionType: RuleActionType
    var command: String
    var isEnabled: Bool
    var isDefault: Bool
    
    init(id: UUID = UUID(), name: String, triggerFile: String, actionIcon: String, actionType: RuleActionType = .terminal, command: String, isEnabled: Bool = true, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.triggerFile = triggerFile
        self.actionIcon = actionIcon
        self.actionType = actionType
        self.command = command
        self.isEnabled = isEnabled
        self.isDefault = isDefault
    }
    
    static let defaults: [ContextRule] = [
        ContextRule(name: "Open Repo", triggerFile: ".git", actionIcon: "globe", actionType: .url, command: #"git remote get-url origin | sed 's/git@github.com:/https:\/\/github.com\//' | sed 's/\.git$//'"#, isDefault: true),
        ContextRule(name: "npm start", triggerFile: "package.json", actionIcon: "play.circle.fill", actionType: .terminal, command: "npm start", isDefault: true),
        ContextRule(name: "Install Deps", triggerFile: "package.json", actionIcon: "arrow.down.circle.fill", actionType: .terminal, command: "npm install", isDefault: true),
        ContextRule(name: "Docker Up", triggerFile: "docker-compose.yml", actionIcon: "shippingbox.fill", actionType: .terminal, command: "docker-compose up -d", isDefault: true),
        ContextRule(name: "mvn install", triggerFile: "pom.xml", actionIcon: "cup.and.saucer.fill", actionType: .terminal, command: "mvn clean install", isDefault: true),
        ContextRule(name: "cargo run", triggerFile: "Cargo.toml", actionIcon: "gearshape.fill", actionType: .terminal, command: "cargo run", isDefault: true)
    ]
}
