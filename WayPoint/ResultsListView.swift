import SwiftUI

struct ResultsListView: View {
    @ObservedObject var vm: WayPointViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if vm.filteredItems.isEmpty {
                    EmptyStateView(isSearching: vm.isSearching, query: vm.query)
                } else {
                    ListRows(items: vm.filteredItems, selectedIndex: vm.selectedIndex, vm: vm)
                }
            }
            .onChange(of: vm.scrollTargetId) { _, newValue in
                if let targetId = newValue {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(targetId, anchor: .center)
                    }
                }
            }
        }
    }
}

struct ListRows: View {
    let items: [PathItem]
    let selectedIndex: Int
    @ObservedObject var vm: WayPointViewModel

    var body: some View {
        LazyVStack(spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isFootprints = vm.activeTab == .history && vm.query.isEmpty
                
                ResultRow(
                    item: item,
                    isSelected: index == selectedIndex,
                    isMinimal: isFootprints,
                    isLast: index == items.count - 1, // 传入最后一行标记
                    dateHeader: isFootprints && shouldShowDateHeader(at: index) ? dateTitle(for: item.lastVisitedAt) : nil
                ) { actionType in
                    vm.executeAction(type: actionType, targetItem: item)
                }
                .id(item.id)
                .onTapGesture {
                    vm.selectedIndex = index
                    vm.executeAction(type: .open)
                }
            }
        }
    }
    
    private func shouldShowDateHeader(at index: Int) -> Bool {
        if index == 0 { return true }
        let calendar = Calendar.current
        let currentItem = items[index]
        let previousItem = items[index - 1]
        return !calendar.isDate(currentItem.lastVisitedAt, inSameDayAs: previousItem.lastVisitedAt)
    }
    
    private func dateTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return NSLocalizedString("Today", comment: "") }
        if calendar.isDateInYesterday(date) { return NSLocalizedString("Yesterday", comment: "") }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
}
