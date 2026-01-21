//
//  KeyablePanel.swift
//  WayPoint
//
//  Created by Gemini on 2026/1/16.
//

import Cocoa
import Quartz

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    // 允许预览面板控制
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }
    
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.delegate = self
        panel.dataSource = self
    }
    
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.delegate = nil
        panel.dataSource = nil
    }
}

extension KeyablePanel: QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return AppDelegate.shared?.currentPreviewURL != nil ? 1 : 0
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        // 必须返回 NSURL 才能正确响应 QLPreviewItem 协议
        return AppDelegate.shared?.currentPreviewURL as NSURL?
    }
    
    // 让预览窗口跟随主窗口移动
    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        return self.frame
    }
}