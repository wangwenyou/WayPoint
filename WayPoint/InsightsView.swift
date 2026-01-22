import SwiftUI

struct InsightsData {
    let todayCount: Int
    let weeklyCount: Int
    let totalCount: Int
    let topPath: String?
    let timeSavedSeconds: Int
    let actionDistribution: [(name: String, count: Int)]
    let weeklyTrend: [Int] // 过去 7 天每日跳转次数
}

struct InsightsView: View {
    @ObservedObject var storage = StorageManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    var stats: InsightsData {
        let now = Date()
        let calendar = Calendar.current
        
        // 1. 基础计数
        let todayRecords = storage.jumpHistory.filter { calendar.isDateInToday($0.timestamp) }
        let startOf7DaysAgo = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let weeklyRecords = storage.jumpHistory.filter { $0.timestamp >= startOf7DaysAgo }
        
        // 2. 最常去目的地
        let groupedPaths = Dictionary(grouping: weeklyRecords, by: { $0.path })
        let topPath = groupedPaths.max(by: { $0.value.count < $1.value.count })?.key
        
        // 3. 动作分布
        let groupedActions = Dictionary(grouping: storage.jumpHistory, by: { $0.actionType })
        let actionDist = groupedActions.map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)
        
        // 4. 过去 7 天趋势
        var trend: [Int] = []
        for i in 0...6 {
            let date = calendar.date(byAdding: .day, value: -i, to: now) ?? now
            let count = storage.jumpHistory.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }.count
            trend.insert(count, at: 0)
        }
        
        // 5. 加权时间节省计算
        let totalSaved = storage.jumpHistory.reduce(0) { sum, record in
            var weight = 10 // 默认 Finder 跳转 10s
            if record.actionType == "Inject" { weight = 30 }
            else if record.actionType.hasPrefix("Rule:") { weight = 20 }
            else if record.actionType == "Editor" || record.actionType == "Terminal" { weight = 15 }
            return sum + weight
        }
        
        return InsightsData(
            todayCount: todayRecords.count,
            weeklyCount: weeklyRecords.count,
            totalCount: storage.jumpHistory.count,
            topPath: topPath,
            timeSavedSeconds: totalSaved,
            actionDistribution: Array(actionDist),
            weeklyTrend: trend
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xxl) {
                InsightsHeader()
                
                StatsGrid(stats: stats)
                
                HStack(alignment: .top, spacing: DesignSystem.Spacing.xl) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        SectionHeader(title: "Activity Trend", icon: "chart.bar.fill")
                        TrendChart(data: stats.weeklyTrend)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        SectionHeader(title: "Top Actions", icon: "bolt.horizontal.fill")
                        ActionList(actions: stats.actionDistribution)
                    }
                    .frame(width: 220)
                }
                
                if let path = stats.topPath {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        SectionHeader(title: "Top Destination", icon: "crown.fill")
                        TopDestinationCard(path: path)
                    }
                }
                
                Spacer().frame(height: 20)
            }
            .padding(DesignSystem.Spacing.xxl)
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(.blue)
            Text(NSLocalizedString(title, comment: "")).font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
        }.padding(.bottom, 4)
    }
}

struct TrendChart: View {
    let data: [Int]
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            let maxVal = Swift.max(data.max() ?? 1, 1)
            ForEach(0..<data.count, id: \.self) { i in
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.6)]), startPoint: .top, endPoint: .bottom))
                        .frame(height: CGFloat(data[i]) / CGFloat(maxVal) * 100 + 4)
                    
                    Text("\(data[i])")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
}

struct ActionList: View {
    let actions: [(name: String, count: Int)]
    var body: some View {
        VStack(spacing: 10) {
            if actions.isEmpty {
                Text(NSLocalizedString("No records yet", comment: "")).font(.caption).foregroundColor(.secondary).padding()
            }
            ForEach(actions, id: \.name) { action in
                HStack {
                    Text(NSLocalizedString(action.name, comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(action.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(DesignSystem.CornerRadius.medium)
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