import SwiftUI
import Combine

struct WayPointView: View {
    @ObservedObject var vm: WayPointViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
                ZStack {
                    // 背景材质
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .ignoresSafeArea()
                    
                    // Raycast 背景叠加 (浅色模式下应用 #F2F3F5)
                    if colorScheme == .light {
                        ColorTheme.raycastGray
                            .ignoresSafeArea()
                    }
                    
                    VStack(spacing: 0) {                if !vm.showSettings {
                    MainWindowContent(vm: vm, showSettings: $vm.showSettings)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.02)),
                            removal: .opacity.combined(with: .scale(scale: 0.98))
                        ))
                } else {
                    SettingsView(isPresented: $vm.showSettings, selectedTab: $vm.settingsTab, vm: vm)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
            }
            
            WindowBorder()
            
            // 重命名弹窗
            if vm.renamingItem != nil {
                RenameDialogView(vm: vm)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .frame(width: 720, height: 540)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.window, style: .continuous))
        .environmentObject(vm)
        .animation(DesignSystem.Animation.spring, value: vm.showSettings)
    }
}

struct MainWindowContent: View {
    @ObservedObject var vm: WayPointViewModel
    @Binding var showSettings: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            TopSearchBar(vm: vm, showSettings: $showSettings)
            
            Divider()
                .background(ColorTheme.Border.secondary(colorScheme))
            
            ResultsListView(vm: vm)
            
            Divider()
                .background(ColorTheme.Border.secondary(colorScheme))
            
            BottomBar(vm: vm)
        }
    }
}

private struct WindowBorder: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.window, style: .continuous)
            .stroke(ColorTheme.Border.primary(colorScheme), lineWidth: 1)
            .ignoresSafeArea()
    }
}