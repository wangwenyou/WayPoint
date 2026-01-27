import SwiftUI

struct PathDetailView: View {
    let item: PathItem
    @ObservedObject var vm: WayPointViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部预览区域
            VStack(spacing: DesignSystem.Spacing.md) {
                FileIconView(path: item.path, isSelected: false, size: 80)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                
                VStack(spacing: 4) {
                    Text(item.alias)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let tech = item.technology {
                        Text(tech)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(.top, 32)
            .padding(.bottom, 24)
            
            Divider()
                .background(ColorTheme.Border.secondary(colorScheme))
            
            // 信息列表
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    DetailSection(title: NSLocalizedString("Location", comment: "")) {
                        Text(item.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(6)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(4)
                            .onTapGesture {
                                vm.executeAction(type: .open, targetItem: item)
                            }
                            .help(NSLocalizedString("Click to open in Finder", comment: ""))
                    }
                    
                    if let status = item.statusSummary {
                        DetailSection(title: NSLocalizedString("Status", comment: "")) {
                            Text(status)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    DetailSection(title: NSLocalizedString("Usage", comment: "")) {
                        HStack(spacing: 24) {
                            UsageStat(label: NSLocalizedString("Visits", comment: ""), value: "\(item.visitCount)")
                            UsageStat(label: NSLocalizedString("Score", comment: ""), value: "\(Int(item.score))")
                        }
                    }
                    
                    if !item.actions.isEmpty {
                        DetailSection(title: NSLocalizedString("Context Actions", comment: "")) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(item.actions, id: \.self) { action in
                                    InteractiveRow(icon: action.icon, label: NSLocalizedString(action.title, comment: ""), iconColor: .orange) {
                                        vm.executeAction(type: .contextAction(action), targetItem: item)
                                    }
                                }
                            }
                        }
                    }
                    
                    DetailSection(title: NSLocalizedString("Shortcuts", comment: "")) {
                        VStack(alignment: .leading, spacing: 4) {
                            InteractiveRow(key: "↵", label: NSLocalizedString("Open in Finder", comment: "")) {
                                vm.executeAction(type: .open, targetItem: item)
                            }
                            InteractiveRow(key: "⌘↵", label: NSLocalizedString("Inject to Dialog", comment: "")) {
                                vm.executeAction(type: .inject, targetItem: item)
                            }
                            InteractiveRow(key: "⌥↵", label: NSLocalizedString("Open in Editor", comment: "")) {
                                vm.executeAction(type: .editor, targetItem: item)
                            }
                            InteractiveRow(key: "⌘T", label: NSLocalizedString("Open in Terminal", comment: "")) {
                                vm.executeAction(type: .terminal, targetItem: item)
                            }
                            InteractiveRow(key: "⌘C", label: NSLocalizedString("Copy Path", comment: "")) {
                                vm.executeAction(type: .copy, targetItem: item)
                            }
                            InteractiveRow(key: "Space", label: NSLocalizedString("Quick Look Preview", comment: "")) {
                                vm.executeAction(type: .preview, targetItem: item)
                            }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
        }
        .background(ColorTheme.Background.adaptive(colorScheme).opacity(0.5))
    }
}

// MARK: - 可交互行组件
struct InteractiveRow: View {
    var icon: String? = nil
    var key: String? = nil
    let label: String
    var iconColor: Color = .secondary
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundColor(iconColor)
                        .frame(width: 14)
                } else if let key = key {
                    Text(key)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 32, alignment: .leading)
                }
                
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.primary.opacity(0.8))
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.7))
                .textCase(.uppercase)
            
            content()
        }
    }
}

struct UsageStat: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}
