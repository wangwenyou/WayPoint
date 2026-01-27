import SwiftUI
import Combine

struct WayPointView: View {
    @ObservedObject var vm: WayPointViewModel
    @ObservedObject var storage = StorageManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // 背景材质与颜色叠加
            if colorScheme == .light {
                ColorTheme.raycastGray
                    .ignoresSafeArea()
                VisualEffectView(material: .windowBackground, blendingMode: .withinWindow)
                    .ignoresSafeArea()
                    .opacity(0.5)
            } else {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                if !vm.showSettings {
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
        .background(ColorTheme.Background.adaptive(colorScheme))
        .frame(width: (vm.showDetail && !vm.showSettings) ? 980 : 720, height: 540)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.window, style: .continuous))
        .environmentObject(vm)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.showDetail)
        .animation(DesignSystem.Animation.spring, value: vm.showSettings)
        .preferredColorScheme(preferredScheme)
    }
    
    private var preferredScheme: ColorScheme? {
        switch storage.appAppearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct MainWindowContent: View {
    @ObservedObject var vm: WayPointViewModel
    @Binding var showSettings: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                TopSearchBar(vm: vm, showSettings: $showSettings)
                
                Divider()
                    .background(ColorTheme.Border.secondary(colorScheme))
                
                ResultsListView(vm: vm)
                
                Divider()
                    .background(ColorTheme.Border.secondary(colorScheme))
                
                BottomBar(vm: vm)
            }
            .frame(width: 720)
            
            if vm.showDetail && vm.filteredItems.indices.contains(vm.selectedIndex) {
                Divider()
                    .background(ColorTheme.Border.secondary(colorScheme))
                
                PathDetailView(item: vm.filteredItems[vm.selectedIndex], vm: vm)
                    .frame(width: 260)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
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