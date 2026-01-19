//
//  SettingsView.swift
//  WayPoint
//
//  Created by Gemini on 2026/1/16.
//

import SwiftUI
import Carbon

struct SettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var shortcutManager = LocalShortcutManager.shared
    @StateObject var updateChecker = UpdateChecker.shared
    @StateObject var languageManager = LanguageManager.shared
    
    @State private var keysString: String = NSLocalizedString("Press to Record", comment: "")
    @State private var isRecordingGlobal = false
    @State private var recordingAction: LocalAction?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(NSLocalizedString("Settings", comment: ""))
                    .font(.headline)
                Spacer()
                Button(NSLocalizedString("Done", comment: "")) {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            TabView {
                // Tab 1: General
                GeneralSettingsView(
                    keysString: $keysString,
                    isRecordingGlobal: $isRecordingGlobal,
                    languageManager: languageManager,
                    onUpdateShortcut: { event in updateShortcut(event: event) }
                )
                .tabItem {
                    Label(NSLocalizedString("General", comment: ""), systemImage: "gear")
                }
                
                // Tab 2: Shortcuts
                ActionShortcutsView(
                    shortcutManager: shortcutManager,
                    recordingAction: $recordingAction,
                    onUpdate: { action, event in
                        // 提取字符：优先使用 charactersIgnoringModifiers，去掉空白
                        let char = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
                        shortcutManager.updateShortcut(action: action, keyChar: char, keyCode: event.keyCode, modifiers: event.modifierFlags)
                    }
                )
                .tabItem {
                    Label(NSLocalizedString("Shortcuts", comment: ""), systemImage: "keyboard")
                }
                
                // Tab 3: Exclusions
                ExcludedPathsView(storage: storage)
                .tabItem {
                    Label(NSLocalizedString("Exclusions", comment: ""), systemImage: "xmark.bin")
                }
                
                // Tab 4: Insights
                InsightsView()
                .tabItem {
                    Label(NSLocalizedString("Insights", comment: ""), systemImage: "chart.bar")
                }
                
                // Tab 5: About & Update
                AboutSettingsView(updateChecker: updateChecker)
                .tabItem {
                    Label(NSLocalizedString("About", comment: ""), systemImage: "info.circle")
                }
            }
            .padding(10)
        }
        .frame(width: 500, height: 450)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            loadCurrentShortcut()
        }
    }
    
    // MARK: - Logic
    
    private func loadCurrentShortcut() {
        let code = UserDefaults.standard.integer(forKey: "SavedHotKeyCode")
        let mods = UserDefaults.standard.integer(forKey: "SavedHotKeyModifiers")
        
        if code == 0 {
            keysString = "⌥ Space"
        } else {
            keysString = formatShortcut(keyCode: code, modifiers: mods)
        }
    }
    
    private func updateShortcut(event: NSEvent) {
        let keyCode = UInt32(event.keyCode)
        let modifiers = event.modifierFlags
        
        var carbonMods: UInt32 = 0
        if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if modifiers.contains(.option) { carbonMods |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
        if modifiers.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        
        HotKeyManager.shared.updateHotKey(keyCode: keyCode, modifiers: carbonMods)
        
        keysString = formatShortcut(keyCode: Int(keyCode), modifiers: Int(carbonMods))
        isRecordingGlobal = false
    }
    
    private func formatShortcut(keyCode: Int, modifiers: Int) -> String {
        var str = ""
        if (modifiers & cmdKey) != 0 { str += "⌘ " }
        if (modifiers & controlKey) != 0 { str += "⌃ " }
        if (modifiers & optionKey) != 0 { str += "⌥ " }
        if (modifiers & shiftKey) != 0 { str += "⇧ " }
        
        if keyCode == kVK_Space {
            str += "Space"
        } else if keyCode == 36 {
            str += "↵"
        } else if keyCode == 51 {
            str += "⌫"
        } else {
            // 这里简单处理，实际可根据 keyCode 获取字符
            str += "Key(\(keyCode))"
        }
        return str
    }
}

// MARK: - Subviews

struct GeneralSettingsView: View {
    @Binding var keysString: String
    @Binding var isRecordingGlobal: Bool
    @ObservedObject var languageManager: LanguageManager
    var onUpdateShortcut: (NSEvent) -> Void
    
    var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("Language", comment: ""))) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: $languageManager.currentLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(NSLocalizedString("Please restart the app to apply language changes.", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer() 
                        
                        Button(NSLocalizedString("Restart Now", comment: "")) {
                            languageManager.restartApp()
                        }
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }
            
            Section(header: Text(NSLocalizedString("Global Shortcut", comment: ""))) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("Main Hotkey to toggle WayPoint", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        isRecordingGlobal = true
                    }) {
                        Text(isRecordingGlobal ? NSLocalizedString("Type Shortcut...", comment: "") : keysString)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .background(ShortcutRecorderView(isRecording: $isRecordingGlobal, onRecord: onUpdateShortcut))
                    
                    Text(NSLocalizedString("Click to record a new shortcut", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }
        }
        .padding()
        .scrollContentBackground(.hidden)
    }
}

struct AboutSettingsView: View {
    @ObservedObject var updateChecker: UpdateChecker
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .frame(width: 80, height: 80)
            
            VStack(spacing: 8) {
                Text("WayPoint")
                    .font(.title)
                    .fontWeight(.bold)
                
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("\(NSLocalizedString("Version", comment: "")) \(version) (Build \(build))")
                        .foregroundColor(.secondary)
                }
            }
            
            Divider().frame(width: 200)
            
            VStack(spacing: 12) {
                if updateChecker.isChecking {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(NSLocalizedString("Check for Updates", comment: "")) {
                        updateChecker.checkForUpdates(manual: true)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Text("© 2026 Wang Wenyou")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(isPresented: $updateChecker.showUpdateAlert) {
            if let update = updateChecker.updateAvailable {
                let langCode = Locale.current.language.languageCode?.identifier ?? "en"
                let isZh = langCode.lowercased().contains("zh")
                let notes = update.releaseNotes[isZh ? "zh-Hans" : "en"] ?? update.releaseNotes["en"] ?? ""
                
                return Alert(
                    title: Text(NSLocalizedString("New Version Available", comment: "")),
                    message: Text("\(NSLocalizedString("Version", comment: "")) \(update.version) (Build \(update.build))\n\n\(notes)"),
                    primaryButton: .default(Text(NSLocalizedString("Download", comment: "")), action: {
                        updateChecker.openDownloadLink()
                    }),
                    secondaryButton: .cancel()
                )
            } else if let error = updateChecker.lastError {
                return Alert(
                    title: Text("Error"),
                    message: Text(error),
                    dismissButton: .default(Text("OK"))
                )
            } else {
                return Alert(
                    title: Text(NSLocalizedString("Up to Date", comment: "")),
                    message: Text(NSLocalizedString("You are using the latest version.", comment: "")),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

struct ActionShortcutsView: View {
    @ObservedObject var shortcutManager: LocalShortcutManager
    @Binding var recordingAction: LocalAction?
    var onUpdate: (LocalAction, NSEvent) -> Void
    
    var body: some View {
        VStack {
            List {
                Section(header: Text(NSLocalizedString("Customize Action Shortcuts", comment: ""))) {
                    ForEach(LocalAction.allCases) { action in
                        HStack {
                            Text(NSLocalizedString(action.rawValue, comment: ""))
                            Spacer() 
                            
                            Button(action: {
                                recordingAction = action
                            }) {
                                Text(recordingAction == action ? NSLocalizedString("Recording...", comment: "") : shortcutManager.shortcut(for: action).displayString)
                                    .frame(width: 120)
                            }
                            .buttonStyle(.bordered)
                            .background(
                                Group {
                                    if recordingAction == action {
                                        ShortcutRecorderView(isRecording: Binding(
                                            get: { recordingAction == action },
                                            set: { if !$0 { recordingAction = nil } }
                                        )) { event in
                                            onUpdate(action, event)
                                            recordingAction = nil
                                        }
                                    }
                                }
                            )
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            
            Button(NSLocalizedString("Reset to Defaults", comment: "")) {
                shortcutManager.resetToDefaults()
            }
            .padding()
        }
    }
}

struct ExcludedPathsView: View {
    @ObservedObject var storage: StorageManager
    
    var body: some View {
        VStack {
            List {
                if storage.excludedPaths.isEmpty {
                    Text(NSLocalizedString("No excluded paths", comment: ""))
                        .foregroundColor(.secondary)
                        .italic()
                        .padding()
                } else {
                    ForEach(Array(storage.excludedPaths).sorted(), id: \.self) {
                        path in
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.secondary)
                            Text(path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(path)
                            
                            Spacer() 
                            
                            Button(action: {
                                storage.unexclude(path: path)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            
            Text(NSLocalizedString("Select a path in search results and press ⌘Delete to exclude it.", comment: ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
        }
    }
}

// 隐藏的 View，用于监听按键
struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onRecord: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = ShortcutRecorderNSView()
        view.onKeyDown = { event in
            if isRecording {
                onRecord(event)
                return true
            }
            return false
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? ShortcutRecorderNSView {
            view.isRecording = isRecording
            if isRecording {
                DispatchQueue.main.async {
                    view.window?.makeFirstResponder(view)
                }
            }
        }
    }
}

class ShortcutRecorderNSView: NSView {
    var isRecording = false
    var onKeyDown: ((NSEvent) -> Bool)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if let handler = onKeyDown, handler(event) {
            return
        }
        super.keyDown(with: event)
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isRecording {
             if let handler = onKeyDown, handler(event) {
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
