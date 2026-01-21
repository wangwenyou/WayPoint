import SwiftUI
import AppKit

struct NativeDropdown: NSViewRepresentable {
    let options: [AppOption]
    @Binding var selection: String
    let onChooseOther: () -> Void
    
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.bezelStyle = .rounded
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectionChanged(_:))
        return button
    }
    
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        // 1. 重建菜单
        button.removeAllItems()
        
        // 添加预设选项
        for option in options {
            let localizedName = NSLocalizedString(option.name, comment: "")
            let item = NSMenuItem(title: localizedName, action: nil, keyEquivalent: "")
            item.representedObject = option.id
            
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: option.id) {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            } else {
                let icon = NSImage(systemSymbolName: "app", accessibilityDescription: nil)
                icon?.size = NSSize(width: 16, height: 16)
                item.image = icon
            }
            button.menu?.addItem(item)
        }
        
        // 添加分割线
        button.menu?.addItem(NSMenuItem.separator())
        
        // 2. 处理自定义选中项
        if !options.contains(where: { $0.id == selection }) {
            let customName = getCustomName(for: selection)
            let item = NSMenuItem(title: customName, action: nil, keyEquivalent: "")
            item.representedObject = selection
            
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: selection) {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            }
            // 插入到分割线之前
            button.menu?.insertItem(item, at: options.count)
        }
        
        // 3. 添加“选择其他...”
        let otherItem = NSMenuItem(title: NSLocalizedString("Choose...", comment: ""), action: #selector(Coordinator.chooseOther(_:)), keyEquivalent: "")
        otherItem.target = context.coordinator
        otherItem.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil)
        button.menu?.addItem(otherItem)
        
        // 4. 设置选中态
        let idx = button.indexOfItem(withRepresentedObject: selection)
        if idx >= 0 {
            button.selectItem(at: idx)
        }
    }
    
    private func getCustomName(for id: String) -> String {
        if id == StorageManager.shared.preferredEditor { return StorageManager.shared.getEditorDisplayName() }
        if id == StorageManager.shared.preferredTerminal { return StorageManager.shared.getTerminalDisplayName() }
        return id
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: NativeDropdown
        
        init(_ parent: NativeDropdown) {
            self.parent = parent
        }
        
        @objc func selectionChanged(_ sender: Any?) {
            guard let popup = sender as? NSPopUpButton,
                  let item = popup.selectedItem,
                  let id = item.representedObject as? String else { return }
            
            if !id.isEmpty && id != parent.selection {
                parent.selection = id
            }
        }
        
        @objc func chooseOther(_ sender: Any?) {
            // 这里不再需要寻找 superview，只需执行选择逻辑
            parent.onChooseOther()
        }
    }
}