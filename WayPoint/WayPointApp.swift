//
//  WayPointApp.swift
//  WayPoint
//
//  Created by wangwenyou on 2026/1/15.
//

import SwiftUI

@main
struct WayPointApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // 使用 Settings 场景来承载系统级的 Cmd+, 指令
        // 但我们不提供实际内容，而是通过 AppDelegate 手动接管逻辑
        Settings {
            // 这是一个几乎不可见的占位符
            Color.clear
                .frame(width: 1, height: 1)
                .onAppear {
                    // 彻底修复：当系统尝试打开这个设置窗口时（按下 Cmd+,），
                    // 我们立即拦截并调用自己的 showAbout 逻辑，然后关闭这个多余的窗口
                    appDelegate.showAbout()
                    for window in NSApplication.shared.windows {
                        if window.title == "" || window.className.contains("SwiftUI") {
                            // 查找并关闭这个由 Settings 产生的空白窗口
                            if window.frame.width < 100 { window.close() }
                        }
                    }
                }
        }
    }
}
