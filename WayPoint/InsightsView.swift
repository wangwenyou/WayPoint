import SwiftUI

struct InsightsData {
    let todayCount: Int
    let weeklyCount: Int
    let totalCount: Int
    let topPath: String?
    let timeSavedSeconds: Int
}

struct InsightsView: View {
    @ObservedObject var storage = StorageManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    var stats: InsightsData {
        let now = Date()
        let calendar = Calendar.current
        let todayRecords = storage.jumpHistory.filter { calendar.isDateInToday($0.timestamp) }
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let weeklyRecords = storage.jumpHistory.filter { $0.timestamp >= startOfWeek }
        let grouped = Dictionary(grouping: weeklyRecords, by: { $0.path })
        let topPath = grouped.max(by: { $0.value.count < $1.value.count })?.key
        return InsightsData(
            todayCount: todayRecords.count,
            weeklyCount: weeklyRecords.count,
            totalCount: storage.jumpHistory.count,
            topPath: topPath,
            timeSavedSeconds: storage.jumpHistory.count * 10
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xxl) {
                InsightsHeader()
                StatsGrid(stats: stats)
                if let path = stats.topPath { TopDestinationCard(path: path) }
                Spacer()
            }
            .padding(DesignSystem.Spacing.xxl)
        }
    }
}

struct InsightsHeader: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("WayPoint Insights", comment: ""))
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundColor(.primary)
                Text(NSLocalizedString("Your productivity dashboard", comment: ""))
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(.secondary)
            }
            Spacer()
            ZStack {
                Circle().fill(Color.blue.opacity(0.15)).frame(width: 56, height: 56)
                Image(systemName: "chart.pie.fill").font(.system(size: 24, weight: .medium)).foregroundColor(.blue)
            }
        }.padding(.top, DesignSystem.Spacing.sm)
    }
}

struct StatsGrid: View {
    let stats: InsightsData
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: DesignSystem.Spacing.lg), GridItem(.flexible(), spacing: DesignSystem.Spacing.lg)],
            spacing: DesignSystem.Spacing.lg
        ) {
            StatCard(title: NSLocalizedString("Jumps Today", comment: ""), value: "\(stats.todayCount)", icon: "bolt.fill", gradient: [Color.orange, Color.yellow])
            StatCard(title: NSLocalizedString("Jumps Weekly", comment: ""), value: "\(stats.weeklyCount)", icon: "calendar", gradient: [Color.blue, Color.cyan])
            StatCard(title: NSLocalizedString("Time Saved", comment: ""), value: formatTime(seconds: stats.timeSavedSeconds), icon: "clock.fill", gradient: [Color.green, Color.mint])
            StatCard(title: NSLocalizedString("Total Jumps", comment: ""), value: "\(stats.totalCount)", icon: "sparkles", gradient: [Color.purple, Color.indigo])
        }
    }
    private func formatTime(seconds: Int) -> String {
        let mins = seconds / 60
        if seconds < 60 { return "\(seconds)\(NSLocalizedString("seconds", comment: ""))" }
        if mins < 60 { return "\(mins)\(NSLocalizedString("minutes", comment: ""))" }
        let hours = mins / 60
        return hours < 24 ? "\(hours)\(NSLocalizedString("hours", comment: "")) \(mins % 60)\(NSLocalizedString("minutes", comment: ""))" : "\(hours / 24)\(NSLocalizedString("days", comment: "")) \(hours % 24)\(NSLocalizedString("hours", comment: ""))"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                ZStack {
                    Circle().fill(LinearGradient(gradient: Gradient(colors: gradient.map { $0.opacity(0.15) }), startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundColor(gradient.first)
                }
                Spacer()
                Text(title).font(DesignSystem.Typography.caption).foregroundColor(.secondary)
            }
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.lg)
        .cardStyle(colorScheme)
    }
}

struct TopDestinationCard: View {
    let path: String
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack {
                Text(NSLocalizedString("Top Destination (Weekly)", comment: ""))
                    .font(DesignSystem.Typography.headline).foregroundColor(.primary)
                Spacer()
                Image(systemName: "crown.fill").font(.system(size: 16, weight: .medium)).foregroundColor(.orange)
            }
            HStack(spacing: DesignSystem.Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium).fill(Color.blue.opacity(0.1)).frame(width: 44, height: 44)
                    Image(systemName: "folder.fill").font(.system(size: 18, weight: .medium)).foregroundColor(.blue)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text((path as NSString).lastPathComponent).font(DesignSystem.Typography.headline).foregroundColor(.primary).lineLimit(1)
                    Text(path).font(DesignSystem.Typography.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
            .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .padding(DesignSystem.Spacing.lg)
        .cardStyle(colorScheme)
    }
}