import SwiftUI

struct EmptyStateView: View {
    let isSearching: Bool
    let query: String
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            
            if isSearching {
                ProgressView().scaleEffect(0.8)
                Text("Searching File System...")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                EmptyStateIcon(query: query)
                EmptyStateText(query: query)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct EmptyStateIcon: View {
    let query: String
    var body: some View {
        Image(systemName: query.isEmpty ? "folder.badge.questionmark" : "magnifyingglass")
            .font(.system(size: 40))
            .foregroundColor(.secondary.opacity(0.2))
    }
}

struct EmptyStateText: View {
    let query: String
    var body: some View {
        VStack(spacing: 4) {
            Text(query.isEmpty ? "No items found" : "No local matches")
                .font(.headline)
                .foregroundColor(.secondary.opacity(0.8))
            
            if !query.isEmpty {
                Text("Press Return ↵ to search File System")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
    }
}

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
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? Color.primary.opacity(0.1) : Color.clear)
            .foregroundColor(isActive ? .primary : .secondary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct ShortcutLabel: View {
    let key: String
    let label: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.primary.opacity(0.1))
                .cornerRadius(4)
                .foregroundColor(.secondary)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.8))
        }
    }
}
