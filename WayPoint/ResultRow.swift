import SwiftUI
import AppKit

// 快捷键提示组件
struct ShortcutHint: View {
    let label: LocalizedStringKey
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
        }
    }
}

// 列表单行视图
struct ResultRow: View {
    let item: PathItem
    let isSelected: Bool
    let onAction: (WayPointViewModel.ActionType) -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            HStack(spacing: 12) {
                // 图标容器 - 借鉴设计，增加背景
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.white.opacity(0.2) : Color.blue.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    FileIconView(path: item.path, isFavorite: item.isFavorite, isSelected: isSelected)
                        .frame(width: 24, height: 24)
                }
                
                // 文件夹名称和路径
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.alias)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .primary)
                        
                        if item.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(isSelected ? .white : .yellow)
                        }
                        
                        // 权重标识 (微小的数字)
                        if item.visitCount > 0 {
                            Text("\(item.visitCount)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.05))
                                .cornerRadius(4)
                                .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary.opacity(0.5))
                                .help("Frecency Score: \(Int(item.score))")
                        }
                    }
                    
                    Text(item.path)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? Color.white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                
                Spacer()
                
                // 交互提示 (右侧显示)
                if isSelected && !isHovering {
                    HStack(spacing: 6) {
                        Image(systemName: "command")
                            .font(.system(size: 10))
                        Image(systemName: "return")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(4)
                    .foregroundColor(.white)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                isSelected 
                ? Color.blue.opacity(0.9) 
                : (isHovering ? Color.primary.opacity(0.05) : Color.clear)
            )
            .cornerRadius(10)
            
            // 悬浮工具栏 (当悬停时显示)
            if isHovering {
                 HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ActionButton(icon: "arrowshape.turn.up.right.fill", help: "Inject to Dialog", isSelected: isSelected) { onAction(.inject) }
                        ActionButton(icon: "arrow.turn.up.left", help: "Open in Finder", isSelected: isSelected) { onAction(.open) }
                        ActionButton(icon: "t.square", help: "Open in Terminal", isSelected: isSelected) { onAction(.terminal) }
                        ActionButton(icon: "chevron.left.forwardslash.chevron.right", help: "Open in Editor", isSelected: isSelected) { onAction(.editor) }
                        ActionButton(icon: "doc.on.doc", help: "Copy Path", isSelected: isSelected) { onAction(.copy) }
                        ActionButton(icon: item.isFavorite ? "star.slash" : "star", help: item.isFavorite ? "Unfavorite" : "Favorite", isSelected: isSelected) { onAction(.toggleFavorite) }
                    }
                    .padding(.trailing, 12)
                }
            }
        }
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

struct ActionButton: View {
    let icon: String
    let help: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
        .help(Text(help))
    }
}

// 真实文件图标组件
struct FileIconView: View {
    let path: String
    let isFavorite: Bool
    let isSelected: Bool
    
    @State private var icon: NSImage?
    
    var body: some View {
        ZStack {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "folder.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(isSelected ? .white : Color(NSColor.systemBlue))
            }
        }
        .onAppear {
            loadIcon()
        }
    }
    
    private func loadIcon() {
        let url = URL(fileURLWithPath: path)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 64, height: 64)
        self.icon = icon
    }
}
