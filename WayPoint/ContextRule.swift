import Foundation

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
    var name: String        // 既是规则名称，也是按钮标签
    var triggerFile: String
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
        ContextRule(name: "Docker Up", triggerFile: "docker-compose.yml", actionIcon: "shippingbox.fill", actionType: .terminal, command: "docker-compose up -d", isDefault: true),
        ContextRule(name: "mvn install", triggerFile: "pom.xml", actionIcon: "cup.and.saucer.fill", actionType: .terminal, command: "mvn clean install", isDefault: true),
        ContextRule(name: "cargo run", triggerFile: "Cargo.toml", actionIcon: "gearshape.fill", actionType: .terminal, command: "cargo run", isDefault: true)
    ]
}
