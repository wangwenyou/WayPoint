import SwiftUI

struct SettingsOverlay: View {
    @Binding var showSettings: Bool
    
    var body: some View {
        if showSettings {
            ZStack {
                Color.black.opacity(0.15)
                    .onTapGesture { showSettings = false }
                
                SettingsView(isPresented: $showSettings)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .shadow(color: Color.black.opacity(0.3), radius: 20)
            }
        } else {
            EmptyView()
        }
    }
}
