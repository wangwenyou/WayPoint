import SwiftUI
import Combine

struct VersionInfo: Codable {
    let version: String
    let build: Int
    let releaseNotes: [String: String]
    let downloadUrl: String
    let releaseDate: String?
    let minOSVersion: String?
}

class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    
    @Published var isChecking = false
    @Published var updateAvailable: VersionInfo? = nil
    @Published var lastError: String? = nil
    @Published var showUpdateAlert = false
    
    // 指向 GitHub 仓库中 version.json 的 Raw 地址
    private let checkUrl = URL(string: "https://raw.githubusercontent.com/wangwenyou/WayPoint/main/version.json")!
    
    private init() {}
    
    func checkForUpdates(manual: Bool = false) {
        isChecking = true
        lastError = nil
        // 关键修复：开始检查前清空之前的更新信息，防止残留导致逻辑判断错误
        updateAvailable = nil 
        
        URLSession.shared.dataTask(with: checkUrl) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isChecking = false
                
                if let error = error {
                    if manual { self?.lastError = error.localizedDescription; self?.showUpdateAlert = true }
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    let info = try JSONDecoder().decode(VersionInfo.self, from: data)
                    self?.compareVersion(info: info, manual: manual)
                } catch {
                    print("JSON Decode error: \(error)")
                    if manual { self?.lastError = "Invalid version data"; self?.showUpdateAlert = true }
                }
            }
        }.resume()
    }
    
    private func compareVersion(info: VersionInfo, manual: Bool) {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let currentBuildStr = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
              let currentBuild = Int(currentBuildStr) else {
            return
        }
        
        // 比较版本号：OrderedDescending 表示 info.version (服务器) > currentVersion (本地)
        let serverVersionIsNewer = info.version.compare(currentVersion, options: .numeric) == .orderedDescending
        let serverVersionIsSame = info.version.compare(currentVersion, options: .numeric) == .orderedSame
        let serverBuildIsNewer = info.build > currentBuild
        
        // 只有当服务器版本更新，或者版本号相同但服务器 Build 更高时，才提示更新
        if serverVersionIsNewer || (serverVersionIsSame && serverBuildIsNewer) {
            self.updateAvailable = info
            self.showUpdateAlert = true
        } else {
            self.updateAvailable = nil
            if manual {
                self.lastError = nil
                self.showUpdateAlert = true
            }
        }
    }
    
    func openDownloadLink() {
        guard let urlStr = updateAvailable?.downloadUrl, let url = URL(string: urlStr) else { return }
        NSWorkspace.shared.open(url)
    }
}
