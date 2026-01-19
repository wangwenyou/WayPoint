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
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            updateLanguage(currentLanguage)
        }
    }
    
    private init() {
        let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        if let preferred = languages?.first {
            if let lang = AppLanguage.allCases.first(where: { $0.rawValue == preferred }) {
                self.currentLanguage = lang
                return
            }
            // 处理 zh-Hans-CN 这种情况
            if preferred.starts(with: "zh-Hans") { self.currentLanguage = .simplifiedChinese; return }
            if preferred.starts(with: "zh-Hant") { self.currentLanguage = .traditionalChinese; return }
            if preferred.starts(with: "en") { self.currentLanguage = .english; return }
        }
        self.currentLanguage = .system
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
