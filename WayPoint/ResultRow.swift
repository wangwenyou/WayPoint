import SwiftUI
import AppKit

// MARK: - Components

struct TagBadge: View {
    let tag: String
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
                .symbolRenderingMode(.palette)
                .foregroundStyle(iconPrimaryColor, iconSecondaryColor)
                .font(.system(size: 8, weight: .semibold))
            
            Text(NSLocalizedString(tag, comment: ""))
                .font(.system(size: 8, weight: .medium))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .foregroundColor(textColor)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(borderColor, lineWidth: 0.5)
        )
    }
    
    var iconName: String {
        switch tag {
        case "Code": return "chevron.left.forwardslash.chevron.right"
        case "Design": return "paintbrush.fill"
        default: return "tag.fill"
        }
    }
    
    var iconPrimaryColor: Color {
        if isSelected { return .white }
        switch tag {
        case "Code": return .blue
        case "Design": return .purple
        default: return .gray
        }
    }
    
    var iconSecondaryColor: Color {
        iconPrimaryColor.opacity(0.5)
    }
    
    var backgroundColor: Color {
        if isSelected { return Color.white.opacity(0.2) }
        switch tag {
        case "Code": return Color.blue.opacity(0.12)
        case "Design": return Color.purple.opacity(0.12)
        default: return ColorTheme.Background.adaptive(colorScheme)
        }
    }
    
    var textColor: Color {
        if isSelected { return .white }
        switch tag {
        case "Code": return .blue
        case "Design": return .purple
        default: return ColorTheme.Text.mediumContrast(colorScheme)
        }
    }
    
    var borderColor: Color {
        if isSelected { return Color.white.opacity(0.3) }
        return iconPrimaryColor.opacity(0.2)
    }
}

struct TechBadge: View {
    let tech: String
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: techIcon)
                .symbolRenderingMode(.palette)
                .foregroundStyle(primaryColor, secondaryColor)
                .font(.system(size: 8, weight: .semibold))
            
            Text(tech)
                .font(.system(size: 8, weight: .medium))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .foregroundColor(textColor)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(borderColor, lineWidth: 0.5)
        )
    }
    
    private var techIcon: String {
        let lowerTech = tech.lowercased()
        if lowerTech.contains("node") || lowerTech.contains("npm") {
            return "hexagon.fill"
        } else if lowerTech.contains("python") {
            return "terminal.fill"
        } else if lowerTech.contains("swift") {
            return "swift"
        } else if lowerTech.contains("rust") {
            return "gearshape.2.fill"
        } else if lowerTech.contains("go") {
            return "g.circle.fill"
        } else if lowerTech.contains("java") {
            return "cup.and.saucer.fill"
        } else if lowerTech.contains("docker") {
            return "shippingbox.fill"
        } else if lowerTech.contains("git") {
            return "arrow.triangle.branch"
        } else {
            return "terminal.fill"
        }
    }
    
    private var primaryColor: Color {
        if isSelected { return .white }
        let lowerTech = tech.lowercased()
        if lowerTech.contains("node") || lowerTech.contains("npm") {
            return .green
        } else if lowerTech.contains("python") {
            return Color(red: 0.25, green: 0.47, blue: 0.76)
        } else if lowerTech.contains("swift") {
            return .orange
        } else if lowerTech.contains("rust") {
            return Color(red: 0.87, green: 0.35, blue: 0.20)
        } else if lowerTech.contains("go") {
            return .cyan
        } else if lowerTech.contains("java") {
            return Color(red: 0.93, green: 0.29, blue: 0.15)
        } else if lowerTech.contains("docker") {
            return Color(red: 0.13, green: 0.52, blue: 0.84)
        } else if lowerTech.contains("git") {
            return Color(red: 0.95, green: 0.35, blue: 0.18)
        } else {
            return .gray
        }
    }
    
    private var secondaryColor: Color {
        primaryColor.opacity(0.5)
    }
    
    private var backgroundColor: Color {
        if isSelected { return Color.white.opacity(0.2) }
        return primaryColor.opacity(0.12)
    }
    
    private var textColor: Color {
        isSelected ? .white : primaryColor
    }
    
    private var borderColor: Color {
        if isSelected { return Color.white.opacity(0.3) }
        return primaryColor.opacity(0.2)
    }
}



// MARK: - Main Row

struct ResultRow: View {
    let item: PathItem
    let isSelected: Bool
    var isMinimal: Bool = false
    var isLast: Bool = false // 新增：标记是否为最后一行
    var dateHeader: String? = nil // 新增：如果是该日期第一项，则传入标题内容
    let onAction: (WayPointViewModel.ActionType) -> Void
    
    @ObservedObject var storage = StorageManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        ZStack(alignment: .trailing) { // 关键修改：靠右对齐
            HStack(spacing: 0) {
                // --- 左侧时间轴 (极简模式：左侧时间 + 轴线) ---
                if isMinimal {
                    HStack(spacing: 0) {
                        // 1. 时间标签 (stacked date/time)
                        VStack(alignment: .trailing, spacing: 0) {
                            if let header = dateHeader {
                                Text(header)
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(isSelected ? .white : Color.blue.opacity(0.8))
                                    .padding(.bottom, 2)
                            }
                            
                            Text(item.lastVisitedAt, style: .time)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : Color.primary.opacity(0.25))
                        }
                        .frame(width: 60, alignment: .trailing)
                        .padding(.trailing, 12)
                        
                        // 2. 轴线和圆点
                        ZStack {
                            // 轴线 (贯穿整行)
                            Rectangle()
                                .fill(isSelected ? Color.white.opacity(0.3) : Color.primary.opacity(0.06))
                                .frame(width: 1)
                                .padding(.vertical, -DesignSystem.Spacing.lg)
                            
                            // 锚点 (根据是否是新日期显示不同样式)
                            if dateHeader != nil {
                                // 新日期起始点：更大的环
                                Circle()
                                    .strokeBorder(isSelected ? Color.white : Color.blue.opacity(0.5), lineWidth: 2)
                                    .background(Circle().fill(isSelected ? .white.opacity(0.2) : Color.blue.opacity(0.1)))
                                    .frame(width: 10, height: 10)
                            } else {
                                // 普通节点：实心小点
                                Circle()
                                    .fill(isSelected ? Color.white : Color.primary.opacity(0.15))
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .frame(width: 20)
                    }
                    .padding(.leading, 12)
                    .padding(.top, dateHeader != nil ? 16 : 0) // 给新的一天留出更多间距
                }
                
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
                                
                                if item.isFavorite {
                                    Image(systemName: "star.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(
                                            isSelected ? .white : .yellow,
                                            isSelected ? Color.white.opacity(0.5) : Color.orange
                                        )
                                        .font(.system(size: 10, weight: .semibold))
                                        .shadow(color: isSelected ? .clear : .yellow.opacity(0.3), radius: 2)
                                }
                                
                                if !isMinimal && storage.showResultTags {
                                    HStack(spacing: 4) {
                                        ForEach(item.tags, id: \.self) { tag in
                                            TagBadge(tag: tag, isSelected: isSelected)
                                        }
                                        if let tech = item.technology, !item.tags.contains(where: { tech.contains($0) || $0.contains(tech) }) {
                                            TechBadge(tech: tech, isSelected: isSelected)
                                        }
                                    }
                                }
                                
                                if !isMinimal && storage.showResultScore {
                                    Text(String(format: "%.1f", item.score))
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundColor(isSelected ? .white.opacity(0.6) : ColorTheme.Text.lowContrast(colorScheme).opacity(0.8))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(isSelected ? Color.white.opacity(0.1) : Color.primary.opacity(0.04)))
                                }
                            }
                            
                            HStack(spacing: 4) {
                                Text(item.path)
                                    .font(DesignSystem.Typography.resultSubtitle)
                                    .foregroundColor(isSelected ? .white.opacity(0.7) : ColorTheme.Text.lowContrast(colorScheme))
                                    .lineLimit(1)
                                    .truncationMode(.head)
                                
                                if !isMinimal && storage.showResultInfo, let status = item.statusSummary {
                                    Text("•")
                                        .font(DesignSystem.Typography.resultSubtitle)
                                        .foregroundColor(isSelected ? .white.opacity(0.5) : ColorTheme.Text.lowContrast(colorScheme))
                                    Text(status)
                                        .font(DesignSystem.Typography.resultSubtitle)
                                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                                        .lineLimit(1)
                                }
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
                .padding(.trailing, DesignSystem.Spacing.lg)
                .padding(.leading, isMinimal ? 0 : DesignSystem.Spacing.lg)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading) // 确保占满整行宽度
            .background(isSelected ? Color.blue.opacity(0.85) : (isHovering ? ColorTheme.Interactive.hover(colorScheme) : Color.clear))
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .contentShape(Rectangle()) // 扩大由于 Spacer 导致的空白区域的点击和 Hover 范围
            
            if isHovering {
                HoverActionToolbar(item: item, isSelected: isSelected, isLast: isLast, onAction: onAction)
                    .padding(.trailing, 8) // 靠右留出一点边距
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
    let isLast: Bool // 新增
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
                    isContextual: true,
                    tooltipOnTop: isLast // 最后一行向上弹
                ) {
                    onAction(.contextAction(action))
                }
                // 小分割线
                Divider().frame(height: 16).padding(.horizontal, 4)
            }
            
            // 可配置的标准动作
            ForEach(storage.enabledToolbarActions) { actionType in
                SeamlessActionButton(
                    icon: getIcon(for: actionType),
                    help: getHelpText(for: actionType),
                    isSelected: isSelected,
                    tooltipOnTop: isLast // 最后一行向上弹
                ) {
                    triggerStandardAction(actionType)
                }
            }
        }
    }
    
    private func getIcon(for type: StandardAction) -> String {
        if type == .toggleFavorite {
            return item.isFavorite ? "star.slash.fill" : "star"
        }
        return type.icon
    }
    
    private func getHelpText(for type: StandardAction) -> LocalizedStringKey {
        if type == .toggleFavorite {
            return LocalizedStringKey(item.isFavorite ? "Unfavorite" : "Favorite")
        }
        return LocalizedStringKey(type.label)
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
    var tooltipOnTop: Bool = false // 新增：控制 Tooltip 弹出方向
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // 触发点击动画
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                isPressed = true
            }
            
            // 执行操作
            action()
            
            // 恢复状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: 32, height: 32)
                .background(backgroundColor)
                .cornerRadius(6)
                .scaleEffect(scale)
                .rotationEffect(rotation)
        }
        .buttonStyle(.plain)
        .overlay(
            Group {
                if isHovering {
                    Text(help)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(4)
                        .shadow(radius: 2)
                        .fixedSize()
                        .zIndex(100)
                        .offset(y: tooltipOnTop ? -28 : 28) // 自适应方向
                        .transition(.opacity.animation(.easeOut(duration: 0.15)))
                }
            },
            alignment: tooltipOnTop ? .top : .bottom
        )
        // 移除系统的 .help(Text(help))，因为它太慢且不稳定
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
    }
    }
    
    private var scale: CGFloat {
        if isPressed { return 0.85 }
        if isHovering { return 1.1 }
        return 1.0
    }
    
    private var rotation: Angle {
        // 上下文动作有轻微旋转效果
        if isContextual && isHovering {
            return .degrees(3)
        }
        return .degrees(0)
    }
    
    private var foregroundColor: Color {
        if isPressed { 
            let baseColor: Color = isSelected ? .white : (isContextual ? .orange : .blue)
            return baseColor.opacity(0.7) 
        }
        if isSelected { return .white }
        if isContextual { return isHovering ? .orange : Color.orange.opacity(0.8) }
        return isHovering ? (colorScheme == .dark ? Color.white : Color.black) : Color.secondary
    }
    
    private var backgroundColor: Color {
        if isPressed {
            if isSelected { return Color.white.opacity(0.3) }
            if isContextual { return Color.orange.opacity(0.3) }
            return (colorScheme == .dark ? Color.white : Color.black).opacity(0.15)
        }
        if isHovering {
            if isSelected { return Color.white.opacity(0.2) }
            if isContextual { return Color.orange.opacity(0.15) }
            return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
        }
        return Color.clear
    }
}
