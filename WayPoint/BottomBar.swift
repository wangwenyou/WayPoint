import SwiftUI

struct BottomBar: View {
    @ObservedObject var vm: WayPointViewModel
    
    var body: some View {
        if vm.filteredItems.indices.contains(vm.selectedIndex) {
            VStack(spacing: 0) {
                Divider().opacity(0.5)
                HStack {
                    BottomBarShortcuts()
                    Spacer()
                    BottomBarItemCount(count: vm.filteredItems.count)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.2))
            }
        } else {
            EmptyView()
        }
    }
}

struct BottomBarShortcuts: View {
    @ObservedObject var shortcutManager = LocalShortcutManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            ShortcutLabel(key: shortcutManager.shortcut(for: .inject).displayString, label: "Inject")
            ShortcutLabel(key: shortcutManager.shortcut(for: .editor).displayString, label: "Editor")
            ShortcutLabel(key: shortcutManager.shortcut(for: .terminal).displayString, label: "Term")
            ShortcutLabel(key: shortcutManager.shortcut(for: .toggleFavorite).displayString, label: "Fav")
            ShortcutLabel(key: shortcutManager.shortcut(for: .exclude).displayString, label: "Exclude")
        }
    }
}

struct BottomBarItemCount: View {
    let count: Int
    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .fontWeight(.semibold)
            Text("items")
        }
        .font(.system(size: 10))
        .foregroundColor(.secondary.opacity(0.7))
        .textCase(.uppercase)
    }
}
