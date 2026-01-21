import Foundation
import AppKit
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "System Default"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return NSLocalizedString("System Default", comment: "")
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    // 记录应用启动时的初始语言
    let originalLanguage: AppLanguage
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            updateLanguage(currentLanguage)
        }
    }
    
    private init() {
        let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        let initial: AppLanguage
        
        if let preferred = languages?.first {
            if let lang = AppLanguage.allCases.first(where: { $0.rawValue == preferred }) {
                initial = lang
            } else if preferred.starts(with: "zh-Hans") {
                initial = .simplifiedChinese
            } else if preferred.starts(with: "zh-Hant") {
                initial = .traditionalChinese
            } else if preferred.starts(with: "en") {
                initial = .english
            } else {
                initial = .system
            }
        } else {
            initial = .system
        }
        
        self.currentLanguage = initial
        self.originalLanguage = initial
    }
    
    private func updateLanguage(_ language: AppLanguage) {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
    
    func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.bundlePath)
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}