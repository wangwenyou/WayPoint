import SwiftUI

struct InsightsView: View {
    @ObservedObject var storage = StorageManager.shared
    
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
            VStack(spacing: 25) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("WayPoint Insights", comment: ""))
                            .font(.system(size: 24, weight: .bold))
                        Text(NSLocalizedString("Your productivity dashboard", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 50, height: 50)
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.top, 10)
                
                // Main Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    StatCard(
                        title: "Jumps Today",
                        value: "\(stats.todayCount)",
                        icon: "bolt.fill",
                        color: .orange
                    )
                    StatCard(
                        title: "Jumps Weekly",
                        value: "\(stats.weeklyCount)",
                        icon: "calendar",
                        color: .blue
                    )
                    StatCard(
                        title: "Time Saved",
                        value: formatTime(seconds: stats.timeSavedSeconds),
                        icon: "clock.fill",
                        color: .green
                    )
                    StatCard(
                        title: "Total Jumps",
                        value: "\(stats.totalCount)",
                        icon: "sparkles",
                        color: .purple
                    )
                }
                
                // Weekly Top Highlight
                if let path = stats.topPath {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text(NSLocalizedString("Top Destination (Weekly)", comment: ""))
                                .font(.headline)
                            Spacer()
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                        }
                        
                        HStack(spacing: 15) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text((path as NSString).lastPathComponent)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(path)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(12)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                }
                
                Spacer()
            }
            .padding(25)
        }
    }
    
    private func formatTime(seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let mins = seconds / 60
        if mins < 60 { return "\(mins)m" }
        let hours = mins / 60
        if hours < 24 {
            return "\(hours)h \(mins % 60)m"
        } else {
            return "\(hours / 24)d \(hours % 24)h"
        }
    }
}

struct StatCard: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}