import SwiftUI

struct SearchFieldWrapper: View {
    @ObservedObject var vm: WayPointViewModel
    
    var body: some View {
        CustomTextField(
            text: $vm.query,
            placeholder: NSLocalizedString("Search...", comment: ""),
            onUpArrow: { vm.moveSelection(-1) },
            onDownArrow: { vm.moveSelection(1) },
            onReturn: { vm.executeAction(type: .open) },
            onCommandReturn: { vm.executeAction(type: .inject) },
            onOptionReturn: { vm.executeAction(type: .editor) },
            onEscape: { 
                NotificationCenter.default.post(
                    name: NSNotification.Name("closeWayPointWindow"), 
                    object: nil
                ) 
            },
            onCommandT: { vm.executeAction(type: .terminal) },
            onCommandC: { vm.executeAction(type: .copy) },
            onCommandF: { vm.executeAction(type: .toggleFavorite) },
            onCommandDelete: { vm.executeAction(type: .exclude) },
            onTab: { vm.switchTab() }
        )
    }
}
