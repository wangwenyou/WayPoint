import SwiftUI

struct TopSearchBar: View {
    @ObservedObject var vm: WayPointViewModel
    @Binding var showSettings: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            SearchArea(vm: vm, showSettings: $showSettings)
            TabArea(activeTab: vm.activeTab, vm: vm)
        }
        .background(ColorTheme.Background.adaptive(colorScheme))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(ColorTheme.Border.secondary(colorScheme))
                .offset(y: 1),
            alignment: .bottom
        )
    }
}

struct SearchArea: View {
    @ObservedObject var vm: WayPointViewModel
    @Binding var showSettings: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(ColorTheme.Text.secondary)
            
            SearchFieldWrapper(vm: vm)
                .placeholder(NSLocalizedString("Search Paths...", comment: ""))
            
            SettingsButton(showSettings: $showSettings)
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.vertical, DesignSystem.Spacing.lg)
    }
}

struct SettingsButton: View {
    @Binding var showSettings: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {
            withAnimation(DesignSystem.Animation.spring) { 
                showSettings = true 
            }
        }) {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isHovering ? ColorTheme.Text.primary : ColorTheme.Text.secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isHovering ? ColorTheme.Interactive.hover : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovering = hovering
            }
        }
    }
}

struct TabArea: View {
    let activeTab: WayPointTab
    @ObservedObject var vm: WayPointViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            TabButton(
                title: "Recent", 
                icon: "clock.arrow.circlepath", 
                isActive: activeTab == .recent
            ) {
                withAnimation(DesignSystem.Animation.springQuick) { 
                    vm.activeTab = .recent 
                }
            }
            
            TabButton(
                title: "Favorites", 
                icon: "star", 
                isActive: activeTab == .favorites
            ) {
                withAnimation(DesignSystem.Animation.springQuick) { 
                    vm.activeTab = .favorites 
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }
}
