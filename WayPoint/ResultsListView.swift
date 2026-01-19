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
                ResultRow(item: item, isSelected: index == selectedIndex) { actionType in
                    vm.executeAction(type: actionType, targetItem: item)
                }
                .id(item.id)
                .onTapGesture {
                    vm.selectedIndex = index
                    vm.executeAction(type: .open)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
