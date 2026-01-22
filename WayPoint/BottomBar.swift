import SwiftUI

struct BottomBar: View {
    @ObservedObject var vm: WayPointViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.1)
            HStack {
                // 左侧：洞察入口
                InsightsEntryButton(vm: vm)
                
                Spacer()
                
                // 中间：快捷键提示 (仅在有选择时显示)
                if vm.filteredItems.indices.contains(vm.selectedIndex) {
                    BottomBarShortcuts()
                }
                
                Spacer()
                
                // 右侧：项目计数
                BottomBarItemCount(count: vm.filteredItems.count)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

struct InsightsEntryButton: View {
    @ObservedObject var vm: WayPointViewModel
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {
            withAnimation(DesignSystem.Animation.spring) {
                vm.showSettings = true
                vm.settingsTab = 7 // Insights 标签的 tag 是 7
            }
        }) {
            HStack(spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .frame(width: 18, height: 18)
                    .shadow(radius: 1)
                
                if isHovering {
                    Text(NSLocalizedString("Insights", comment: ""))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .padding(4)
            .background(isHovering ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .help(NSLocalizedString("View Insights", comment: ""))
    }
}

struct BottomBarShortcuts: View {
    @ObservedObject var shortcutManager = LocalShortcutManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // 使用 LocalizedStringKey 确保翻译生效
            ShortcutLabel(key: shortcutManager.shortcut(for: .inject).displayString, label: "Inject")
            ShortcutLabel(key: shortcutManager.shortcut(for: .editor).displayString, label: "Editor")
            ShortcutLabel(key: shortcutManager.shortcut(for: .terminal).displayString, label: "Term")
            ShortcutLabel(key: shortcutManager.shortcut(for: .toggleFavorite).displayString, label: "Fav")
            ShortcutLabel(key: shortcutManager.shortcut(for: .preview).displayString, label: "Preview")
            ShortcutLabel(key: shortcutManager.shortcut(for: .exclude).displayString, label: "Exclude Path")
        }
    }
}

struct BottomBarItemCount: View {
    let count: Int
    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .fontWeight(.semibold)
            Text(NSLocalizedString("items", comment: ""))
        }
        .font(.system(size: 10))
        .foregroundColor(.secondary.opacity(0.7))
        .textCase(.uppercase)
    }
}