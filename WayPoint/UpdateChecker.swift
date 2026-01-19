import SwiftUI
import Combine

struct VersionInfo: Codable {
    let version: String
    let build: Int
    let releaseDate: String
    let releaseNotes: [String: String]
    let downloadUrl: String
    let minOSVersion: String
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
        
        // 简单比较：先比 Version String，再比 Build Number
        let isVersionNewer = info.version.compare(currentVersion, options: .numeric) == .orderedDescending
        let isBuildNewer = info.build > currentBuild
        
        // 如果 Version 更大，或者 Version 相等但 Build 更大
        if isVersionNewer || (info.version == currentVersion && isBuildNewer) {
            self.updateAvailable = info
            self.showUpdateAlert = true
        } else {
            if manual {
                self.lastError = nil // No error, just no update
                self.showUpdateAlert = true // Show "Up to date" alert
            }
        }
    }
    
    func openDownloadLink() {
        guard let urlStr = updateAvailable?.downloadUrl, let url = URL(string: urlStr) else { return }
        NSWorkspace.shared.open(url)
    }
}
