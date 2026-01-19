import SwiftUI
import Combine

// MARK: - Main View (UI 层)
struct WayPointView: View {
    @StateObject var vm = WayPointViewModel()
    @State private var showSettings = false
    
    var body: some View {
        MainWindowContent(vm: vm, showSettings: $showSettings)
            .frame(width: 640, height: 480)
            .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow))
            .cornerRadius(16)
            .overlay(WindowBorder())
    }
}

private struct MainWindowContent: View {
    @ObservedObject var vm: WayPointViewModel
    @Binding var showSettings: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            TopSearchBar(vm: vm, showSettings: $showSettings)
            
            Divider().opacity(0.5)
            
            ResultsListView(vm: vm)
            
            BottomBar(vm: vm)
        }
        .overlay(SettingsOverlay(showSettings: $showSettings))
    }
}

private struct WindowBorder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
    }
}
