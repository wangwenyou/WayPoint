//
//  CustomTextField.swift
//  WayPoint
//
//  Created by Gemini on 2026/1/16.
//

import SwiftUI
import AppKit

// 自定义 TextField，能够正确处理方向键和其他功能键
struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var onUpArrow: () -> Void
    var onDownArrow: () -> Void
    var onReturn: () -> Void
    var onCommandReturn: () -> Void
    var onOptionReturn: () -> Void // 新增：Option + Enter
    var onEscape: () -> Void
    var onCommandT: () -> Void
    var onCommandC: () -> Void
    var onCommandF: () -> Void
    var onCommandDelete: (() -> Void)? // 新增：排除目录
    var onTab: (() -> Void)? // 新增：切换 Tab
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        let textField = KeyInterceptingTextField()
        textField.delegate = context.coordinator
        textField.font = NSFont.systemFont(ofSize: 22, weight: .light) // 增大字体更加清爽
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.placeholderString = placeholder
        
        // 设置回调
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
        
        // 添加到容器视图
        containerView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textField.topAnchor.constraint(equalTo: containerView.topAnchor),
            textField.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // 保存 textField 引用到 coordinator
        context.coordinator.textField = textField
        
        // 多次尝试设置焦点
        DispatchQueue.main.async {
            if let window = textField.window {
                let result = window.makeFirstResponder(textField)
                print("🎯 makeFirstResponder (attempt 1): \(result)")
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let window = textField.window {
                let result = window.makeFirstResponder(textField)
                print("🎯 makeFirstResponder (attempt 2): \(result)")
            }
        }
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let textField = nsView.subviews.first as? NSTextField {
            textField.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomTextField
        weak var textField: NSTextField?
        
        var onUpArrow: (() -> Void)?
        var onDownArrow: (() -> Void)?
        var onReturn: (() -> Void)?
        var onCommandReturn: (() -> Void)?
        var onOptionReturn: (() -> Void)?
        var onEscape: (() -> Void)?
        var onCommandT: (() -> Void)?
        var onCommandC: (() -> Void)?
        var onCommandF: (() -> Void)?
        var onCommandDelete: (() -> Void)?
        var onTab: (() -> Void)?
        
        init(_ parent: CustomTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        // 这个方法会在 NSTextField 的 NSTextView 接收到特殊命令时被调用
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // print("🔑 doCommandBy: \(commandSelector)")
            
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                onUpArrow?()
                return true
            case #selector(NSResponder.moveDown(_:)):
                onDownArrow?()
                return true
            case #selector(NSResponder.insertNewline(_:)):
                // 检查按下的修饰键
                let modifiers = NSEvent.modifierFlags
                if modifiers.contains(.command) {
                    onCommandReturn?()
                } else if modifiers.contains(.option) {
                    onOptionReturn?()
                } else {
                    onReturn?()
                }
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                onEscape?()
                return true
            case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.insertBacktab(_:)):
                onTab?()
                return true
            default:
                return false
            }
        }
    }
}

// 自定义 NSTextField 子类，拦截快捷键
class KeyInterceptingTextField: NSTextField {
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        print("🎯 TextField becomeFirstResponder: \(result)")
        return result
    }
    
    // 拦截 performKeyEquivalent 来处理自定义快捷键
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let delegate = self.delegate as? CustomTextField.Coordinator else {
            return super.performKeyEquivalent(with: event)
        }
        
        // 1. 优先检查可配置的快捷键
        if let action = LocalShortcutManager.shared.match(event: event) {
            print("⌨️ Matched Action: \(action.rawValue)")
            switch action {
            case .inject: delegate.onCommandReturn?()
            case .terminal: delegate.onCommandT?()
            case .editor: delegate.onOptionReturn?()
            case .copyPath: delegate.onCommandC?()
            case .toggleFavorite: delegate.onCommandF?()
            case .exclude: delegate.onCommandDelete?()
            }
            return true
        }
        
        return super.performKeyEquivalent(with: event)
    }
}
