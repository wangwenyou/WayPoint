import Foundation
import ServiceManagement
import os

class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "wayne.WayPoint", category: "LaunchAtLogin")
    
    private let service = SMAppService.mainApp
    
    func updateStatus() {
        let launchAtLogin = UserDefaults.standard.bool(forKey: "LaunchAtLogin")
        
        if launchAtLogin {
            if service.status != .enabled {
                do {
                    try service.register()
                    logger.info("Successfully registered login item")
                } catch {
                    logger.error("Failed to register login item: \(error.localizedDescription)")
                }
            }
        } else {
            if service.status == .enabled {
                service.unregister { error in
                    if let error = error {
                        self.logger.error("Failed to unregister login item: \(error.localizedDescription)")
                    } else {
                        self.logger.info("Successfully unregistered login item")
                    }
                }
            }
        }
    }
    
    var isEnabled: Bool {
        return service.status == .enabled
    }
}
