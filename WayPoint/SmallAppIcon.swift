import SwiftUI
import AppKit

struct SmallAppIcon: View {
    let bundleId: String
    @State private var icon: NSImage?
    
    var body: some View {
        ZStack {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .onAppear { loadIcon() }
        .onChange(of: bundleId) { _ in loadIcon() }
    }
    
    private func loadIcon() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let appIcon = NSWorkspace.shared.icon(forFile: url.path)
            appIcon.size = NSSize(width: 32, height: 32)
            self.icon = appIcon
        } else {
            self.icon = nil
        }
    }
}
