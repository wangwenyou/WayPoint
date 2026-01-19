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
        // 使用 Settings 而不是 WindowGroup，这样启动时不会显示窗口
        Settings {
            EmptyView()
        }
    }
}
