import SwiftUI

struct SearchFieldWrapper: View {
    @ObservedObject var vm: WayPointViewModel
    var placeholder: String = "" // 新增属性
    
    var body: some View {
        CustomTextField(
            text: $vm.query,
            placeholder: placeholder, // 传递给底层的 CustomTextField
            onUpArrow: { vm.moveSelection(-1) },
            onDownArrow: { vm.moveSelection(1) },
            onLeftArrow: { vm.handleLeftArrow() },
            onRightArrow: { vm.handleRightArrow() },
            onReturn: { vm.executeAction(type: .open) },
            onCommandReturn: { vm.executeAction(type: .inject) },
            onOptionReturn: { vm.executeAction(type: .editor) },
            onEscape: {
                if !vm.query.isEmpty {
                    vm.query = ""
                } else {
                    NotificationCenter.default.post(name: NSNotification.Name("closeWayPointWindow"), object: nil)
                }
            },
            onCommandT: { vm.executeAction(type: .terminal) },
            onCommandC: { vm.executeAction(type: .copy) },
            onCommandF: { vm.executeAction(type: .toggleFavorite) },
            onCommandDelete: { vm.executeAction(type: .exclude) },
            onTab: { vm.handleRightArrow() },
            onPreview: { vm.executeAction(type: .preview) },
            onCommandI: { vm.toggleDetail() }
        )
    }
    
    // 提供链式调用支持
    func placeholder(_ text: String) -> SearchFieldWrapper {
        var copy = self
        copy.placeholder = text
        return copy
    }
}