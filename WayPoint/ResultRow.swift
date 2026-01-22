import SwiftUI
import AppKit

// MARK: - Components

struct TagBadge: View {
    let tag: String
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: iconName)
                .font(.system(size: 7, weight: .medium))
            Text(NSLocalizedString(tag, comment: ""))
                .font(.system(size: 8, weight: .medium))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            isSelected ? 
                Color.white.opacity(0.2) : 
                ColorTheme.Background.adaptive(colorScheme)
        )
        .foregroundColor(
            isSelected ? 
                .white : 
                ColorTheme.Text.mediumContrast(colorScheme)
        )
        .cornerRadius(3)
    }
    
    var iconName: String {
        switch tag {
        case "Code": return "terminal"
        case "Design": return "paintbrush"
        default: return "tag"
        }
    }
}

struct TechBadge: View {
    let tech: String
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(tech)
            .font(.system(size: 8, weight: .medium))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                isSelected ? 
                    Color.white.opacity(0.2) : 
                    ColorTheme.Accent.softBlue.opacity(0.1)
            )
            .foregroundColor(isSelected ? .white : ColorTheme.Accent.blue)
            .cornerRadius(3)
    }
}

struct FileIconView: View {
    let path: String
    let isSelected: Bool
    @State private var icon: NSImage?
    
    var body: some View {
        ZStack {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "folder")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(isSelected ? .white : .secondary)
            }
        }
        .onAppear { loadIcon() }
    }
    
    private func loadIcon() {
        let url = URL(fileURLWithPath: path)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 64, height: 64)
        self.icon = icon
    }
}

// MARK: - Main Row

struct ResultRow: View {
    let item: PathItem
    let isSelected: Bool
    let onAction: (WayPointViewModel.ActionType) -> Void
    
    @ObservedObject var storage = StorageManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            HStack(spacing: DesignSystem.Spacing.lg) {
                // 图标
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 32, height: 32)
                    }
                    
                    FileIconView(path: item.path, isSelected: isSelected)
                        .frame(width: 24, height: 24)
                        .shadow(color: Color.black.opacity(isSelected ? 0.1 : 0.05), radius: 1, y: 1)
                }
                .frame(width: 32)
                
                // 内容
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.alias)
                            .font(DesignSystem.Typography.resultTitle)
                            .foregroundColor(isSelected ? .white : ColorTheme.Text.primary)
                            .lineLimit(1)
                        
                        // 显示得分 (权重) - 仅显示整数部分
                        if storage.showResultScore {
                            Text("\(Int(item.score))")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.05))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary.opacity(0.6))
                                .cornerRadius(3)
                        }
                        
                        if item.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundColor(isSelected ? .white.opacity(0.9) : ColorTheme.Accent.yellow)
                        }
                        
                        if storage.showResultTags {
                            if let tech = item.technology {
                                TechBadge(tech: tech, isSelected: isSelected)
                            }
                            
                            // 去重：只显示不与 technology 重复的标签
                            ForEach(item.tags.filter { $0 != item.technology }.prefix(2), id: \.self) { tag in
                                TagBadge(tag: tag, isSelected: isSelected)
                            }
                        }
                        
                        // 精细化状态显示：区分系统时间与脚本输出
                        if storage.showResultInfo, let status = item.statusSummary {
                            // 鲁棒性更强的系统状态判定：只要包含数字和时间单位，通常就是“修改于...”
                            let timeKeywords = ["ago", "前", "Modified", "修改"]
                            let isSystemStatus = timeKeywords.contains { status.contains($0) } || status.contains("Git")
                            
                            Text(isSystemStatus ? "· \(status)" : status)
                                .font(.system(size: 9, weight: isSystemStatus ? .regular : .bold, design: .monospaced))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : (isSystemStatus ? Color.secondary.opacity(0.7) : .blue))
                                .padding(.horizontal, isSystemStatus ? 0 : 4)
                                .padding(.vertical, 1)
                                .background(isSystemStatus ? Color.clear : (isSelected ? Color.white.opacity(0.2) : Color.blue.opacity(0.05)))
                                .cornerRadius(3)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text(item.path)
                            .font(DesignSystem.Typography.resultSubtitle)
                            .foregroundColor(isSelected ? .white.opacity(0.7) : ColorTheme.Text.lowContrast(colorScheme))
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }
                
                Spacer()
                
                if isSelected && !isHovering {
                    HStack(spacing: 4) {
                        Image(systemName: "command").font(.system(size: 9))
                        Image(systemName: "return").font(.system(size: 9))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.2)))
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.85) : (isHovering ? ColorTheme.Interactive.hover : Color.clear))
            .cornerRadius(DesignSystem.CornerRadius.medium)
            
            if isHovering {
                HoverActionToolbar(item: item, isSelected: isSelected, onAction: onAction)
            }
        }
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) { isHovering = hovering }
        }
        .onDrag { NSItemProvider(object: URL(fileURLWithPath: item.path) as NSURL) }
        .onAppear {
            // 只要没有状态摘要，就尝试刷新（解决 actions 非空导致不刷新的问题）
            if item.statusSummary == nil {
                StorageManager.shared.refreshMetadata(for: item.id)
            }
        }
    }
}

struct HoverActionToolbar: View {
    let item: PathItem
    let isSelected: Bool
    let onAction: (WayPointViewModel.ActionType) -> Void
    @ObservedObject var storage = StorageManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            // 智能上下文动作
            ForEach(item.actions, id: \.self) { action in
                SeamlessActionButton(
                    icon: action.icon,
                    help: LocalizedStringKey(action.title),
                    isSelected: isSelected,
                    isContextual: true
                ) {
                    onAction(.contextAction(action))
                }
                // 小分割线
                Divider().frame(height: 16).padding(.horizontal, 4)
            }
            
            // 可配置的标准动作
            ForEach(storage.enabledToolbarActions) { actionType in
                SeamlessActionButton(
                    icon: actionType.icon,
                    help: LocalizedStringKey(actionType.label),
                    isSelected: isSelected
                ) {
                    triggerStandardAction(actionType)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.regularMaterial))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.white.opacity(0.2) : Color.clear, lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(isSelected ? 0.2 : 0.1), radius: 4, y: 2)
        .offset(y: -2)
    }
    
    private func triggerStandardAction(_ type: StandardAction) {
        switch type {
        case .inject: onAction(.inject)
        case .open: onAction(.open)
        case .preview: onAction(.preview)
        case .terminal: onAction(.terminal)
        case .editor: onAction(.editor)
        case .copy: onAction(.copy)
        case .toggleFavorite: onAction(.toggleFavorite)
        case .exclude: onAction(.exclude)
        case .rename: onAction(.rename)
        }
    }
}

struct SeamlessActionButton: View {
    let icon: String
    let help: LocalizedStringKey
    let isSelected: Bool
    var isContextual: Bool = false
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: 32, height: 32)
                .background(isHovering ? hoverColor : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(Text(help))
        .onHover { isHovering = $0 }
    }
    
    private var foregroundColor: Color {
        if isSelected { return .white }
        if isContextual { return Color.orange }
        return isHovering ? (colorScheme == .dark ? .white : .black) : .secondary
    }
    
    private var hoverColor: Color {
        if isSelected { return Color.white.opacity(0.2) }
        return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }
}