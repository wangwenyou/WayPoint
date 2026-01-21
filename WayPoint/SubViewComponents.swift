import SwiftUI

// MARK: - 快捷键标签组件
struct ShortcutLabel: View {
    let key: String
    let label: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.primary.opacity(0.1))
                .cornerRadius(3)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Tab 切换按钮
struct TabButton: View {
    let title: LocalizedStringKey
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color.blue.opacity(0.1) : Color.clear)
            .foregroundColor(isActive ? .blue : .secondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 空状态视图
struct EmptyStateView: View {
    let isSearching: Bool
    let query: String
    
    var body: some View {
        VStack(spacing: 15) {
            Spacer()
            
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
                Text(NSLocalizedString("Searching File System...", comment: ""))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary.opacity(0.3))
                
                VStack(spacing: 5) {
                    Text(NSLocalizedString("No items found", comment: ""))
                        .font(.system(size: 15, weight: .medium))
                    
                    if !query.isEmpty {
                        Text(NSLocalizedString("Press Return ↵ to search File System", comment: ""))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
