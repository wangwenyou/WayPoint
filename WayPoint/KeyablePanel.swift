//
//  KeyablePanel.swift
//  WayPoint
//
//  Created by Gemini on 2026/1/16.
//

import Cocoa

// 自定义 NSPanel 子类，允许成为 key window 以接收键盘输入
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}
