import SwiftUI

struct TopSearchBar: View {
    @ObservedObject var vm: WayPointViewModel
    @Binding var showSettings: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            SearchArea(vm: vm, showSettings: $showSettings)
            TabArea(activeTab: vm.activeTab, vm: vm)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.1))
    }
}

struct SearchArea: View {
    @ObservedObject var vm: WayPointViewModel
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.secondary)
            
            SearchFieldWrapper(vm: vm)
            
            SettingsShortcutHint()
            
            SettingsButton(showSettings: $showSettings)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

struct SettingsShortcutHint: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("⌘")
            Text("S")
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(.secondary.opacity(0.6))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

struct SettingsButton: View {
    @Binding var showSettings: Bool
    var body: some View {
        Button(action: {
            withAnimation { showSettings = true }
        }) {
            Image(systemName: "gearshape")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }
}

struct TabArea: View {
    let activeTab: WayPointTab
    @ObservedObject var vm: WayPointViewModel

    var body: some View {
        HStack(spacing: 20) {
            TabButton(title: "Recent", icon: "clock.arrow.circlepath", isActive: activeTab == .recent) {
                withAnimation(.spring(response: 0.3)) { vm.activeTab = .recent }
            }
            
            TabButton(title: "Favorites", icon: "star", isActive: activeTab == .favorites) {
                withAnimation(.spring(response: 0.3)) { vm.activeTab = .favorites }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
}
