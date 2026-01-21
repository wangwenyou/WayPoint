//
//  CustomTextField.swift
//  WayPoint
//
//  Created by Gemini on 2026/1/16.
//

import SwiftUI
import AppKit
import Quartz

// 自定义 TextField，能够正确处理方向键和其他功能键
struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var onUpArrow: () -> Void
    var onDownArrow: () -> Void
    var onReturn: () -> Void
    var onCommandReturn: () -> Void
    var onOptionReturn: () -> Void
    var onEscape: () -> Void
    var onCommandT: () -> Void
    var onCommandC: () -> Void
    var onCommandF: () -> Void
    var onCommandDelete: (() -> Void)?
    var onTab: (() -> Void)?
    var onPreview: (() -> Void)?
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        let textField = KeyInterceptingTextField()
        textField.delegate = context.coordinator
        textField.font = NSFont.systemFont(ofSize: 16, weight: .regular) // 更现代的字体大小
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.placeholderString = placeholder
        
        // 设置占位符文本样式
        if let placeholderString = textField.placeholderString {
            let placeholderAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: 16, weight: .regular)
            ]
            textField.placeholderAttributedString = NSAttributedString(
                string: placeholderString,
                attributes: placeholderAttributes
            )
        }
        
        context.coordinator.onUpArrow = onUpArrow
        context.coordinator.onDownArrow = onDownArrow
        context.coordinator.onReturn = onReturn
        context.coordinator.onCommandReturn = onCommandReturn
        context.coordinator.onOptionReturn = onOptionReturn
        context.coordinator.onEscape = onEscape
        context.coordinator.onCommandT = onCommandT
        context.coordinator.onCommandC = onCommandC
        context.coordinator.onCommandF = onCommandF
        context.coordinator.onCommandDelete = onCommandDelete
        context.coordinator.onTab = onTab
        context.coordinator.onPreview = onPreview
        
        containerView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textField.topAnchor.constraint(equalTo: containerView.topAnchor),
            textField.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        context.coordinator.textField = textField
        DispatchQueue.main.async {
            if let window = textField.window { window.makeFirstResponder(textField) }
        }
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let textField = nsView.subviews.first as? NSTextField {
            textField.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomTextField
        weak var textField: NSTextField?
        var onUpArrow, onDownArrow, onReturn, onCommandReturn, onOptionReturn, onEscape, onCommandT, onCommandC, onCommandF, onCommandDelete, onTab, onPreview: (() -> Void)?
        
        init(_ parent: CustomTextField) { self.parent = parent }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)): onUpArrow?(); return true
            case #selector(NSResponder.moveDown(_:)): onDownArrow?(); return true
            case #selector(NSResponder.insertNewline(_:)):
                let modifiers = NSEvent.modifierFlags
                if modifiers.contains(.command) { onCommandReturn?() }
                else if modifiers.contains(.option) { onOptionReturn?() }
                else { onReturn?() }
                return true
            case #selector(NSResponder.cancelOperation(_:)): onEscape?(); return true
            case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.insertBacktab(_:)): onTab?(); return true
            default: return false
            }
        }
    }
}

class KeyInterceptingTextField: NSTextField {
    override var acceptsFirstResponder: Bool { true }
    
    // --- 新增：转发预览控制给窗口 ---
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }
    
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        self.window?.beginPreviewPanelControl(panel)
    }
    
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        self.window?.endPreviewPanelControl(panel)
    }
    // ---------------------------
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let delegate = self.delegate as? CustomTextField.Coordinator else {
            return super.performKeyEquivalent(with: event)
        }
        
        if let action = LocalShortcutManager.shared.match(event: event) {
            print("⌨️ Matched Configurable Action: \(action.rawValue)")
            switch action {
            case .inject: delegate.onCommandReturn?()
            case .terminal: delegate.onCommandT?()
            case .editor: delegate.onOptionReturn?()
            case .copyPath: delegate.onCommandC?()
            case .toggleFavorite: delegate.onCommandF?()
            case .exclude: delegate.onCommandDelete?()
            case .preview: delegate.onPreview?()
            }
            return true // 阻止事件继续传递
        }
        return super.performKeyEquivalent(with: event)
    }
}
