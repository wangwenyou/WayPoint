import SwiftUI
import Carbon
import UniformTypeIdentifiers

struct SettingsView: View {
    @Binding var isPresented: Bool
    @Binding var selectedTab: Int
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var shortcutManager = LocalShortcutManager.shared
    @StateObject var updateChecker = UpdateChecker.shared
    @StateObject var languageManager = LanguageManager.shared
    @ObservedObject var vm: WayPointViewModel
    
    @State private var keysString: String = ""
    @State private var isRecordingGlobal = false
    @State private var recordingAction: LocalAction?
    @State private var editingRule: ContextRule? = nil
    
    let editorPresets = [
        AppOption(id: "com.microsoft.VSCode", name: "Visual Studio Code"),
        AppOption(id: "com.todesktop.230313mzl4w4u92", name: "Cursor"),
        AppOption(id: "com.sublimetext.4", name: "Sublime Text"),
        AppOption(id: "dev.zed.Zed", name: "Zed"),
        AppOption(id: "com.jetbrains.intellij", name: "IntelliJ IDEA"),
        AppOption(id: "com.apple.TextEdit", name: "TextEdit")
    ]
    let terminalPresets = [
        AppOption(id: "com.googlecode.iterm2", name: "iTerm2"),
        AppOption(id: "dev.warp.Warp-Stable", name: "Warp"),
        AppOption(id: "com.apple.Terminal", name: "Terminal"),
        AppOption(id: "com.github.wez.wezterm", name: "WezTerm")
    ]
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 固定在顶部的标题栏
                HStack {
                    Text(NSLocalizedString("Settings", comment: "")).font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 25)
                .padding(.top, 25)
                .padding(.bottom, 15)
                .background(Color.primary.opacity(0.02))
                
                // TabView 本身不再包裹外层 ScrollView，确保内部独立滚动
                TabView(selection: $selectedTab) {
                    GeneralSettingsContent(keysString: $keysString, isRecordingGlobal: $isRecordingGlobal, languageManager: languageManager, storage: storage, onUpdateShortcut: updateShortcut)
                        .tabItem { Label(NSLocalizedString("General", comment: ""), systemImage: "gearshape") }.tag(0)
                    
                    ShortcutsSettingsContent(shortcutManager: shortcutManager, storage: storage, editorPresets: editorPresets, terminalPresets: terminalPresets, recordingAction: $recordingAction, onUpdate: updateActionShortcut)
                        .tabItem { Label(NSLocalizedString("Shortcuts", comment: ""), systemImage: "keyboard") }.tag(1)
                    
                    InterfaceSettingsContent(storage: storage)
                        .tabItem { Label(NSLocalizedString("Interface", comment: ""), systemImage: "macwindow") }.tag(2)
                    
                    ExclusionsSettingsContent(storage: storage)
                        .tabItem { Label(NSLocalizedString("Exclusions", comment: ""), systemImage: "eye.slash") }.tag(3)
                    
                    ContextRulesSettingsContent(vm: vm, storage: storage, editingRule: $editingRule)
                        .tabItem { Label(NSLocalizedString("Rules", comment: ""), systemImage: "bolt.horizontal.circle") }.tag(4)
                    
                    TechRulesSettingsContent(storage: storage)
                        .tabItem { Label(NSLocalizedString("Tags", comment: ""), systemImage: "tag") }.tag(5)
                    
                    PredictorSettingsContent(storage: storage)
                        .tabItem { Label(NSLocalizedString("Prediction", comment: ""), systemImage: "wand.and.stars") }.tag(6)
                    
                    ScoringSettingsContent(storage: storage)
                        .tabItem { Label(NSLocalizedString("Scoring", comment: ""), systemImage: "slider.horizontal.3") }.tag(7)
                    
                    InsightsView()
                        .tabItem { Label(NSLocalizedString("Insights", comment: ""), systemImage: "chart.pie") }.tag(8)
                    
                    AboutSettingsView(updateChecker: updateChecker)
                        .tabItem { Label(NSLocalizedString("About", comment: ""), systemImage: "info.circle") }.tag(9)
                }
            }
            
            if vm.showingAddRule || editingRule != nil {
                RuleDetailOverlay(vm: vm, storage: storage, editingRule: $editingRule).transition(.opacity).zIndex(200)
            }
        }.onAppear { loadCurrentShortcut() }
    }
    
    private func loadCurrentShortcut() {
        let code = UserDefaults.standard.integer(forKey: "SavedHotKeyCode")
        let mods = UserDefaults.standard.integer(forKey: "SavedHotKeyModifiers")
        keysString = code == 0 ? "⌥ Space" : formatShortcut(keyCode: code, modifiers: mods)
    }
    
    private func updateShortcut(event: NSEvent) {
        var carbonMods: UInt32 = 0
        if event.modifierFlags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if event.modifierFlags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        HotKeyManager.shared.updateHotKey(keyCode: UInt32(event.keyCode), modifiers: carbonMods)
        keysString = formatShortcut(keyCode: Int(event.keyCode), modifiers: Int(carbonMods))
        isRecordingGlobal = false
    }
    
    private func updateActionShortcut(action: LocalAction, event: NSEvent) {
        let char = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        shortcutManager.updateShortcut(action: action, keyChar: char, keyCode: event.keyCode, modifiers: event.modifierFlags)
    }
    
    private func formatShortcut(keyCode: Int, modifiers: Int) -> String {
        var str = ""
        if (modifiers & Int(cmdKey)) != 0 { str += "⌘ " }
        if (modifiers & Int(controlKey)) != 0 { str += "⌃ " }
        if (modifiers & Int(optionKey)) != 0 { str += "⌥ " }
        if (modifiers & Int(shiftKey)) != 0 { str += "⇧ " }
        let special: [Int: String] = [49: "Space", 36: "↵", 51: "⌫"]
        let keyLabel = special[keyCode] ?? "K\(keyCode)"
        return str + keyLabel
    }
}

// MARK: - Scoring / Algorithm Settings

struct ScoringSettingsContent: View {
    @ObservedObject var storage: StorageManager
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsCard("Algorithm Factors") {
                        VStack(spacing: 16) {
                            SliderRow(
                                label: "Frequency Priority",
                                value: $storage.weightFrequency,
                                range: 0.1...5.0,
                                caption: "Higher values prioritize most visited paths."
                            )
                            Divider()
                            SliderRow(
                                label: "Recency Priority",
                                value: $storage.weightRecency,
                                range: 0.1...5.0,
                                caption: "Higher values make older visits decay faster."
                            )
                            Divider()
                            SliderRow(
                                label: "Context Prediction",
                                value: $storage.weightPrediction,
                                range: 0.0...5.0,
                                caption: "Weight of the 'Predictor' rules (running apps)."
                            )
                        }.padding(12)
                    }.padding(.bottom, 12)
                    
                    SettingsCard("Path Multipliers") {
                        VStack(spacing: 0) {
                            let keys = storage.customPathWeights.keys.sorted()
                            ForEach(keys, id: \.self) { path in
                                PathMultiplierRow(path: path, storage: storage)
                                if path != keys.last { Divider().padding(.horizontal, 15) }
                            }
                            
                            if keys.isEmpty {
                                Text(NSLocalizedString("No custom multipliers", comment: "")).italic().font(.system(size: 11)).foregroundColor(.secondary).padding(15)
                            }
                            
                            Divider()
                            
                            HStack {
                                Button(action: addPath) { Label(NSLocalizedString("Add Path...", comment: ""), systemImage: "plus") }
                                    .buttonStyle(.plain).font(.system(size: 11)).foregroundColor(.blue)
                                Spacer()
                            }.padding(12)
                        }
                    }
                }.padding(20)
            }
            Divider()
            Text(NSLocalizedString("Fine-tune how WayPoint calculates scores to prioritize the paths you need.", comment: ""))
                .font(.system(size: 10)).foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10).padding(.horizontal, 15)
                .background(Color.primary.opacity(0.02))
        }
    }
    
    private func addPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        panel.beginSheetModal(for: AppDelegate.shared.panel) { response in
            if response == .OK, let url = panel.url {
                storage.customPathWeights[url.path] = 0.5 // Default to half weight (demotion) or customizable
            }
        }
    }
}

struct SliderRow: View {
    let label: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let caption: LocalizedStringKey
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 12, weight: .medium))
                Spacer()
                Text(String(format: "%.1fx", value)).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
            }
            HStack {
                Slider(value: $value, in: range)
            }
            Text(caption).font(.system(size: 10)).foregroundColor(.secondary.opacity(0.8))
        }
    }
}

struct PathMultiplierRow: View {
    let path: String
    @ObservedObject var storage: StorageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "folder").font(.system(size: 10)).foregroundColor(.secondary)
                Text(path).font(.system(size: 10, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button(action: { storage.customPathWeights.removeValue(forKey: path) }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary.opacity(0.4))
                }.buttonStyle(.plain)
            }
            HStack {
                Text(NSLocalizedString("Multiplier", comment: "")).font(.system(size: 10)).foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { storage.customPathWeights[path] ?? 1.0 },
                    set: { storage.customPathWeights[path] = $0 }
                ), in: 0.0...2.0, step: 0.1).controlSize(.small)
                Text(String(format: "%.1fx", storage.customPathWeights[path] ?? 1.0))
                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary).frame(width: 30)
            }
        }.padding(.horizontal, 12).padding(.vertical, 8)
    }
}

// MARK: - Interface Settings

struct InterfaceSettingsContent: View {
    @ObservedObject var storage: StorageManager
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SettingsCard("Search Results") {
                    VStack(spacing: 0) {
                        ToggleRow(label: "Show Tags", isOn: $storage.showResultTags)
                        Divider().padding(.horizontal, 15)
                        ToggleRow(label: "Show Scores", isOn: $storage.showResultScore)
                        Divider().padding(.horizontal, 15)
                        ToggleRow(label: "Show Status Info", isOn: $storage.showResultInfo)
                    }
                }.padding(.bottom, 12)
                
                SettingsCard("Floating Toolbar") {
                    VStack(spacing: 0) {
                        Text(NSLocalizedString("Active Actions (Drag to reorder)", comment: ""))
                            .font(.caption).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 15).padding(.top, 10).padding(.bottom, 5)
                        
                        List {
                            ForEach(storage.enabledToolbarActions) { action in
                                HStack {
                                    Image(systemName: "line.3.horizontal").foregroundColor(.secondary)
                                    Image(systemName: action.icon).frame(width: 20)
                                    Text(action.label).font(.system(size: 12))
                                    Spacer()
                                    Button(action: {
                                        if let idx = storage.enabledToolbarActions.firstIndex(of: action) {
                                            storage.enabledToolbarActions.remove(at: idx)
                                        }
                                    }) {
                                        Image(systemName: "minus.circle.fill").foregroundColor(.red)
                                    }.buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                            .onMove { indices, newOffset in
                                storage.enabledToolbarActions.move(fromOffsets: indices, toOffset: newOffset)
                            }
                        }
                        .listStyle(.plain)
                        .frame(maxHeight: .infinity)
                        
                        Divider()
                        
                        HStack {
                            Menu {
                                ForEach(StandardAction.allCases.filter { !storage.enabledToolbarActions.contains($0) }) { action in
                                    Button(action: { storage.enabledToolbarActions.append(action) }) {
                                        Label(action.label, systemImage: action.icon)
                                    }
                                }
                            } label: {
                                Label(NSLocalizedString("Add Action...", comment: ""), systemImage: "plus")
                            }
                            .menuStyle(.borderlessButton)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .disabled(StandardAction.allCases.filter { !storage.enabledToolbarActions.contains($0) }.isEmpty)
                        }
                    }
                }.frame(maxHeight: .infinity)
            }.padding(20)
            
            Divider()
            Text(NSLocalizedString("Customize how search results and the toolbar look and behave.", comment: ""))
                .font(.system(size: 10)).foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10).padding(.horizontal, 15)
                .background(Color.primary.opacity(0.02))
        }
    }
}

struct ToggleRow: View {
    let label: LocalizedStringKey
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            Text(label).font(.system(size: 13))
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().controlSize(.small)
        }.padding(.horizontal, 15).padding(.vertical, 8)
    }
}

// MARK: - Components

struct SettingsTabWrapper<Content: View>: View {

    let content: () -> Content

    var body: some View {

        content()

    }

}

struct SettingsCard<Content: View>: View {
    let title: LocalizedStringKey; let content: Content
    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary).padding(.leading, 4)
            VStack(spacing: 0) { content }.background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04))).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.06), lineWidth: 1))
        }
    }
}

struct SettingsRow<Content: View>: View {
    let label: LocalizedStringKey; let content: Content
    init(label: LocalizedStringKey, @ViewBuilder content: () -> Content) { self.label = label; self.content = content() }
    var body: some View {
        HStack { Text(label).font(.system(size: 13)); Spacer(); content }.padding(.horizontal, 15).padding(.vertical, 10)
    }
}

struct GeneralSettingsContent: View {
    @Binding var keysString: String; @Binding var isRecordingGlobal: Bool; @ObservedObject var languageManager: LanguageManager; @ObservedObject var storage: StorageManager; var onUpdateShortcut: (NSEvent) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsCard("Language") {
                    SettingsRow(label: "App Language") {
                        Picker("", selection: $languageManager.currentLanguage) { ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) } }.labelsHidden().controlSize(.small).frame(width: 150)
                    }
                    if languageManager.currentLanguage != languageManager.originalLanguage {
                        Divider().padding(.horizontal, 15)
                        HStack {
                            Label(NSLocalizedString("Please restart the app to apply language changes.", comment: ""), systemImage: "exclamationmark.triangle.fill").font(.system(size: 10)).foregroundColor(.orange)
                            Spacer(); Button(NSLocalizedString("Restart Now", comment: "")) { languageManager.restartApp() }.controlSize(.small)
                        }.padding(10)
                    }
                }.padding(.bottom, 12)
                SettingsCard("Global Shortcut") {
                    VStack(spacing: 8) {
                        Button(action: { isRecordingGlobal = true }) { Text(isRecordingGlobal ? "..." : keysString).frame(maxWidth: .infinity).padding(.vertical, 4) }.buttonStyle(.bordered).background(ShortcutRecorderView(isRecording: $isRecordingGlobal, onRecord: onUpdateShortcut))
                        Text(NSLocalizedString("Main Hotkey to toggle WayPoint", comment: "")).font(.system(size: 10)).foregroundColor(.secondary)
                        
                        Divider().padding(.vertical, 8)
                        
                        Toggle(NSLocalizedString("Show Time Saved in Menu Bar", comment: ""), isOn: $storage.showMenuBarWidget)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .font(.system(size: 11))
                    }.padding(12)
                }.padding(.bottom, 12)
                
                SettingsCard("Data Management") {
                    HStack(spacing: 20) {
                        Button(NSLocalizedString("Import Settings", comment: "")) {
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.json]
                            NSApp.activate(ignoringOtherApps: true)
                            panel.beginSheetModal(for: AppDelegate.shared.panel) { response in
                                if response == .OK, let url = panel.url {
                                    _ = storage.importSettings(from: url)
                                }
                            }
                        }
                        
                        Button(NSLocalizedString("Export Settings", comment: "")) {
                            if let url = storage.exportSettings() {
                                let panel = NSSavePanel()
                                panel.allowedContentTypes = [.json]
                                panel.nameFieldStringValue = "WayPoint_Settings.json"
                                NSApp.activate(ignoringOtherApps: true)
                                panel.beginSheetModal(for: AppDelegate.shared.panel) { response in
                                    if response == .OK, let target = panel.url {
                                        try? FileManager.default.removeItem(at: target)
                                        try? FileManager.default.copyItem(at: url, to: target)
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                }.padding(.bottom, 12)
            }.padding(20)
        }
    }
}

struct ShortcutsSettingsContent: View {
    @ObservedObject var shortcutManager: LocalShortcutManager; @ObservedObject var storage: StorageManager; let editorPresets: [AppOption]; let terminalPresets: [AppOption]; @Binding var recordingAction: LocalAction?; var onUpdate: (LocalAction, NSEvent) -> Void
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SettingsCard("Action Shortcuts") {
                    let allActions = LocalAction.allCases
                    VStack(spacing: 0) {
                        ForEach(allActions) { action in
                            // 关键：加上 id，强制在 resetToDefaults 时刷新
                            ShortcutRow(action: action, shortcutManager: shortcutManager, recordingAction: $recordingAction, onUpdate: onUpdate)
                                .id(action.rawValue + shortcutManager.shortcut(for: action).displayString)
                            if action != allActions.last { Divider().padding(.horizontal, 15) }
                        }
                        
                        Divider().padding(.horizontal, 15)
                        HStack {
                            Button(NSLocalizedString("Reset to Defaults", comment: "")) { 
                                shortcutManager.resetToDefaults() 
                            }.buttonStyle(.link).font(.system(size: 11))
                            Spacer()
                        }.padding(12)
                    }
                }
                SettingsCard("Preferred Apps") {
                    VStack(spacing: 0) {
                        SettingsRow(label: "Editor") { NativeDropdown(options: editorPresets, selection: $storage.preferredEditor) { chooseApp(for: .editor) }.frame(width: 200) }
                        Divider().padding(.horizontal, 15)
                        SettingsRow(label: "Terminal") { NativeDropdown(options: terminalPresets, selection: $storage.preferredTerminal) { chooseApp(for: .terminal) }.frame(width: 200) }
                    }
                }
            }.padding(20)
        }
    }
    enum AppType { case editor, terminal }
    private func chooseApp(for type: AppType) {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.application]; panel.directoryURL = URL(fileURLWithPath: "/Applications")
        NSApp.activate(ignoringOtherApps: true)
        panel.beginSheetModal(for: AppDelegate.shared.panel) { response in
            if response == .OK, let url = panel.url {
                if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier {
                    let appName = url.deletingPathExtension().lastPathComponent
                    DispatchQueue.main.async { if type == .editor { storage.customEditorName = appName; storage.preferredEditor = bundleId } else { storage.customTerminalName = appName; storage.preferredTerminal = bundleId } }
                }
            }
        }
    }
}

struct ShortcutRow: View {
    let action: LocalAction; @ObservedObject var shortcutManager: LocalShortcutManager; @Binding var recordingAction: LocalAction?; var onUpdate: (LocalAction, NSEvent) -> Void
    var body: some View {
        SettingsRow(label: LocalizedStringKey(action.rawValue)) {
            Button(action: { recordingAction = action }) { Text(recordingAction == action ? "..." : shortcutManager.shortcut(for: action).displayString).frame(width: 100) }.buttonStyle(.bordered).controlSize(.small).background(Group { if recordingAction == action { ShortcutRecorderView(isRecording: Binding(get: { true }, set: { _ in }), onRecord: { onUpdate(action, $0); recordingAction = nil }) } })
        }
    }
}

struct ExclusionsSettingsContent: View {
    @ObservedObject var storage: StorageManager
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SettingsCard("Excluded Paths") {
                    ScrollView {
                        if storage.excludedPaths.isEmpty {
                            Text(NSLocalizedString("No excluded paths", comment: "")).italic().font(.system(size: 11)).foregroundColor(.secondary).padding(15).frame(maxWidth: .infinity)
                        } else {
                            let sorted = Array(storage.excludedPaths).sorted()
                            LazyVStack(spacing: 0) {
                                ForEach(sorted, id: \.self) { path in
                                    HStack {
                                        Image(systemName: "folder.badge.minus").foregroundColor(.secondary)
                                        Text(path).font(.system(size: 10, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                                        Spacer(); Button(action: { storage.unexclude(path: path) }) { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary.opacity(0.4)) }.buttonStyle(.plain)
                                    }.padding(.horizontal, 12).padding(.vertical, 6)
                                    if path != sorted.last { Divider().padding(.horizontal, 15) }
                                }
                            }
                        }
                    }.frame(maxHeight: .infinity)
                }
            }.padding(20)
            
            Divider()
            Text(NSLocalizedString("Select a path in search results and press ⌘Delete to exclude it.", comment: ""))
                .font(.system(size: 10)).foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10).padding(.horizontal, 15)
                .background(Color.primary.opacity(0.02))
        }
    }
}

struct AboutSettingsView: View {
    @ObservedObject var updateChecker: UpdateChecker
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20); Image(nsImage: NSApp.applicationIconImage ?? NSImage()).resizable().frame(width: 80, height: 80)
            VStack(spacing: 8) {
                Text("WayPoint").font(.title).fontWeight(.bold)
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    let vLabel = NSLocalizedString("Version", comment: "")
                    Text("\(vLabel) \(version) (Build \(build))").foregroundColor(.secondary)
                }
            }
            Divider().frame(width: 200)
            VStack(spacing: 12) {
                if updateChecker.isChecking { ProgressView().scaleEffect(0.8) }
                else { 
                    Button(NSLocalizedString("Check for Updates", comment: "")) { updateChecker.checkForUpdates(manual: true) }.buttonStyle(.borderedProminent) 
                }
                
                // 关键修复：添加文字反馈，让用户知道检查结果，防止感觉“没反应”
                if let error = updateChecker.lastError {
                    Text(error).font(.caption).foregroundColor(.red)
                } else if !updateChecker.isChecking && !updateChecker.showUpdateAlert && updateChecker.updateAvailable == nil {
                    // 如果刚手动检查过且没弹窗没报错，说明已经是最新
                }
                
                Text("© 2026 Wang Wenyou").font(.caption2).foregroundColor(.secondary.opacity(0.5))
                
                Button(action: { NSWorkspace.shared.open(URL(string: "https://wangwenyou.github.io/WayPoint/")!) }) {
                    Text("https://wangwenyou.github.io/WayPoint/")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                        .underline()
                }.buttonStyle(.plain)
            }
            Spacer()
        }
        .alert(isPresented: $updateChecker.showUpdateAlert) {
            if let update = updateChecker.updateAvailable {
                let vLabel = NSLocalizedString("Version", comment: "")
                let notes = update.releaseNotes[Locale.current.language.languageCode?.identifier == "zh" ? "zh-Hans" : "en"] ?? ""
                return Alert(title: Text(NSLocalizedString("New Version Available", comment: "")), message: Text("\(vLabel) \(update.version)\n\n\(notes)"), primaryButton: .default(Text(NSLocalizedString("Download", comment: "")), action: { updateChecker.openDownloadLink() }), secondaryButton: .cancel())
            } else if let error = updateChecker.lastError { return Alert(title: Text("Error"), message: Text(error), dismissButton: .default(Text("OK"))) 
            } else { return Alert(title: Text(NSLocalizedString("Up to Date", comment: "")), message: Text(NSLocalizedString("You are using the latest version.", comment: "")), dismissButton: .default(Text("OK"))) }
        }
    }
}

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool; var onRecord: (NSEvent) -> Void
    func makeNSView(context: Context) -> NSView { let view = ShortcutRecorderNSView(); view.onKeyDown = { if isRecording { onRecord($0); return true }; return false }; return view }
    func updateNSView(_ nsView: NSView, context: Context) { if let v = nsView as? ShortcutRecorderNSView, isRecording { DispatchQueue.main.async { v.window?.makeFirstResponder(v) } } }
}

class ShortcutRecorderNSView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?; override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) { if !(onKeyDown?(event) ?? false) { super.keyDown(with: event) } }
    override func performKeyEquivalent(with event: NSEvent) -> Bool { return onKeyDown?(event) ?? false }
}

// MARK: - Context Rules Management

struct ContextRulesSettingsContent: View {
    @ObservedObject var vm: WayPointViewModel; @ObservedObject var storage: StorageManager
    @Binding var editingRule: ContextRule?
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SettingsCard("Rules") {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(storage.contextRules) { rule in
                                    RuleRow(rule: rule, storage: storage, onClick: { editingRule = rule })
                                }
                            }.padding(12)
                        }.frame(maxHeight: .infinity)
                        
                        Divider().padding(.horizontal, 15)
                        HStack {
                            Button(action: { vm.showingAddRule = true }) { Label(NSLocalizedString("Add New Rule", comment: ""), systemImage: "plus") }.buttonStyle(.plain).font(.system(size: 11)).foregroundColor(.blue)
                            Spacer()
                            Button(NSLocalizedString("Restore Defaults", comment: "")) { storage.resetRulesToDefaults() }.buttonStyle(.link).font(.system(size: 11))
                        }.padding(12)
                    }
                }
            }.padding(20)
            
            Divider()
            Text(NSLocalizedString("WayPoint will show quick action buttons when these files are detected.", comment: ""))
                .font(.system(size: 10)).foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10).padding(.horizontal, 15)
                .background(Color.primary.opacity(0.02))
        }
    }
}

struct RuleRow: View {
    let rule: ContextRule; @ObservedObject var storage: StorageManager; let onClick: () -> Void
    @State private var isHovering = false
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { newValue in
                    if let idx = storage.contextRules.firstIndex(where: { $0.id == rule.id }) {
                        storage.contextRules[idx].isEnabled = newValue
                        storage.saveRules()
                    }
                }
            )).labelsHidden().controlSize(.small)
            
            Image(systemName: rule.actionIcon).foregroundColor(rule.isDefault ? .blue : .orange).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(NSLocalizedString(rule.name, comment: "")).font(.system(size: 13, weight: .medium))
                    if rule.isDefault { Text(NSLocalizedString("Built-in", comment: "")).font(.system(size: 8)).padding(.horizontal, 4).background(Capsule().fill(Color.blue.opacity(0.1))).foregroundColor(.blue) }
                }
                
                // 升级逻辑描述：如果 文件夹包含 [触发文件] [动作类型]：[命令摘要]
                HStack(spacing: 4) {
                    Text(NSLocalizedString("If folder contains", comment: "")).foregroundColor(.secondary)
                    Text(rule.triggerFile).foregroundColor(.primary).font(.system(size: 10, design: .monospaced))
                    Text(rule.actionType.displayName).foregroundColor(.secondary)
                    Text(":").foregroundColor(.secondary)
                    Text(rule.command).foregroundColor(.primary).lineLimit(1).font(.system(size: 10, design: .monospaced))
                }.font(.system(size: 10))
            }
            Spacer()
            if !rule.isDefault {
                Button(action: { storage.contextRules.removeAll(where: { $0.id == rule.id }); storage.saveRules() }) { Image(systemName: "trash").foregroundColor(.secondary.opacity(0.5)) }.buttonStyle(.plain)
            }
        }
        .padding(12).background(isHovering ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03)).cornerRadius(8).onHover { isHovering = $0 }.onTapGesture(perform: onClick)
    }
}

struct RuleDetailOverlay: View {
    @ObservedObject var vm: WayPointViewModel; @ObservedObject var storage: StorageManager
    @Binding var editingRule: ContextRule?
    
    @State private var name = ""; @State private var trigger = ""; @State private var command = ""; @State private var actionType: RuleActionType = .terminal; @State private var iconName = "bolt.fill"
    
    // 恰好 24 个，去除了默认规则已占用的：globe, play.circle.fill, shippingbox.fill, cup.and.saucer.fill, gearshape.fill
    private let commonIcons = [
        "bolt.fill", "terminal", "hammer.fill", "server.rack",
        "cpu", "cube.fill", "flask.fill", "rocket.fill",
        "bug.fill", "wrench.adjustable.fill", "chevron.left.forwardslash.chevron.right", "curlybraces",
        "parentheses", "cpu.fill", "memorychip", "network",
        "antenna.radiowaves.left.and.right", "laptopcomputer", "briefcase.fill", "doc.text.fill",
        "folder.fill", "paperplane.fill", "lock.fill", "ant.fill"
    ]
    
    var body: some View {
        let isReadOnly = editingRule?.isDefault ?? false
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea().onTapGesture { close() }
            VStack(spacing: 20) {
                Text(isReadOnly ? NSLocalizedString("View Rule", comment: "") : (editingRule == nil ? NSLocalizedString("Create Context Rule", comment: "") : NSLocalizedString("Edit Rule", comment: ""))).font(.headline)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("Rule Name / Label", comment: "")).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                            TextField(NSLocalizedString("e.g. npm start", comment: ""), text: $name).disabled(isReadOnly)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("Trigger Condition", comment: "")).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                            TextField(NSLocalizedString("If folder contains (e.g. package.json)", comment: ""), text: $trigger).disabled(isReadOnly)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("Action Type", comment: "")).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                            Picker("", selection: $actionType) { ForEach(RuleActionType.allCases, id: \.self) { Text($0.displayName).tag($0) } }.pickerStyle(.segmented).disabled(isReadOnly)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("Shell Command / URL", comment: "")).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                            TextEditor(text: $command).font(.system(size: 11, design: .monospaced)).frame(height: 80).padding(4).background(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2))).disabled(isReadOnly)
                        }
                        
                        // 图标选择部分：彻底移至 ScrollView 的物理底部
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("Button Icon (SF Symbol)", comment: "")).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                            HStack {
                                TextField(NSLocalizedString("Icon Name", comment: ""), text: $iconName).disabled(isReadOnly)
                                Image(systemName: isValidIcon(iconName) ? iconName : "questionmark.square.dashed")
                                    .font(.system(size: 16)).foregroundColor(isValidIcon(iconName) ? .orange : .secondary).frame(width: 30)
                            }
                            if !isReadOnly {
                                Text(NSLocalizedString("Quick Select Icons", comment: "")).font(.system(size: 9)).foregroundColor(.secondary).padding(.top, 4)
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                                    ForEach(commonIcons, id: \.self) { icon in
                                        Button(action: { iconName = icon }) {
                                            Image(systemName: icon).font(.system(size: 14)).frame(width: 28, height: 28)
                                                .background(iconName == icon ? Color.orange.opacity(0.2) : Color.primary.opacity(0.05)).cornerRadius(4)
                                        }.buttonStyle(.plain)
                                    }
                                }.padding(4)
                            }
                        }
                    }.padding(2)
                }.frame(maxHeight: 450)
                
                                HStack {
                    Button(isReadOnly ? NSLocalizedString("Close", comment: "") : NSLocalizedString("Cancel", comment: "")) { close() }
                    Spacer()
                    if !isReadOnly {
                        Button(editingRule == nil ? NSLocalizedString("Add Rule", comment: "") : NSLocalizedString("Save Changes", comment: "")) { save() }.buttonStyle(.borderedProminent).disabled(name.isEmpty || trigger.isEmpty || command.isEmpty)
                    }
                }
            }.padding(25).frame(width: 450).background(VisualEffectView(material: .popover, blendingMode: .withinWindow)).cornerRadius(12).shadow(radius: 20)
        }
        .onAppear { setup() }
    }
    private func setup() {
        if let rule = editingRule { name = rule.name; trigger = rule.triggerFile; command = rule.command; actionType = rule.actionType; iconName = rule.actionIcon } 
        else { name = ""; trigger = ""; command = ""; actionType = .terminal; iconName = "bolt.fill" }
    }
    private func save() {
        if let existing = editingRule {
            if let idx = storage.contextRules.firstIndex(where: { $0.id == existing.id }) {
                storage.contextRules[idx].name = name; storage.contextRules[idx].triggerFile = trigger; storage.contextRules[idx].command = command; storage.contextRules[idx].actionType = actionType; storage.contextRules[idx].actionIcon = iconName
            }
        } else {
            storage.contextRules.append(ContextRule(id: UUID(), name: name, triggerFile: trigger, actionIcon: iconName, actionType: actionType, command: command, isEnabled: true, isDefault: false))
        }
        storage.saveRules(); close()
    }
    private func close() { vm.showingAddRule = false; editingRule = nil }
    private func isValidIcon(_ name: String) -> Bool { return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil }
}

// MARK: - Technology Detection Rules Management

struct TechRulesSettingsContent: View {
    @ObservedObject var storage: StorageManager
    @State private var showingAddTech = false
    @State private var editingTech: TechDetectionRule? = nil
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Global Settings Card for Tech Rules
                SettingsCard("Global Settings") {
                    Toggle(NSLocalizedString("Show Version Number", comment: ""), isOn: $storage.showVersionNumber)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .font(.system(size: 11))
                        .padding(12)
                }.padding(.bottom, 12)
                
                SettingsCard("Tag Detection Rules") {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(storage.techDetectionRules) { rule in
                                    TechRuleRow(rule: rule, storage: storage) { editingTech = rule }
                                    if rule != storage.techDetectionRules.last { Divider().padding(.horizontal, 15) }
                                }
                            }
                        }.frame(maxHeight: .infinity)
                        
                        Divider().padding(.horizontal, 15)
                        HStack {
                            Button(action: { showingAddTech = true }) { Label(NSLocalizedString("Add Tag Rule", comment: ""), systemImage: "plus") }.buttonStyle(.plain).font(.system(size: 11)).foregroundColor(.blue)
                            Spacer()
                            Button(NSLocalizedString("Restore Defaults", comment: "")) { storage.resetTechRules() }.buttonStyle(.link).font(.system(size: 11))
                        }.padding(12)
                    }
                }
            }.padding(20)
            
            Divider()
            Text(NSLocalizedString("Define how WayPoint identifies project types. Use commas for multiple files (OR logic).", comment: ""))
                .font(.system(size: 10)).foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10).padding(.horizontal, 15)
                .background(Color.primary.opacity(0.02))
        }
        .sheet(isPresented: Binding(get: { showingAddTech || editingTech != nil }, set: { if !$0 { showingAddTech = false; editingTech = nil } })) {
            TechRuleDetailOverlay(storage: storage, isPresented: Binding(get: { showingAddTech || editingTech != nil }, set: { if !$0 { showingAddTech = false; editingTech = nil } }), editingRule: editingTech)
        }
    }
}

struct TechRuleRow: View {
    let rule: TechDetectionRule; @ObservedObject var storage: StorageManager; let onClick: () -> Void
    @State private var isHovering = false
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { newValue in
                    if let idx = storage.techDetectionRules.firstIndex(where: { $0.id == rule.id }) {
                        storage.techDetectionRules[idx].isEnabled = newValue
                        storage.saveTechRules()
                    }
                }
            )).labelsHidden().controlSize(.small)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(rule.name).font(.system(size: 13, weight: .bold))
                    if rule.isDefault { Text(NSLocalizedString("Built-in", comment: "")).font(.system(size: 8)).padding(.horizontal, 4).background(Capsule().fill(Color.blue.opacity(0.1))).foregroundColor(.blue) }
                }
                Text(rule.triggerFiles).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            if !rule.isDefault {
                Button(action: { 
                    storage.techDetectionRules.removeAll(where: { $0.id == rule.id })
                    storage.saveTechRules()
                }) { Image(systemName: "trash").foregroundColor(.secondary.opacity(0.5)) }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(isHovering ? Color.primary.opacity(0.03) : Color.clear)
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onClick)
    }
}

struct TechRuleDetailOverlay: View {
    @ObservedObject var storage: StorageManager
    @Binding var isPresented: Bool
    var editingRule: TechDetectionRule? = nil
    @State private var name = ""
    @State private var triggers = ""
    @State private var statusScript = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text(editingRule == nil ? NSLocalizedString("Add Tag Rule", comment: "") : NSLocalizedString("Edit Tag Rule", comment: "")).font(.headline)
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("Tag Name", comment: "")).font(.caption).foregroundColor(.secondary)
                    TextField("e.g. Java", text: $name)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("Trigger Files (OR logic, comma separated)", comment: "")).font(.caption).foregroundColor(.secondary)
                    TextField("e.g. pom.xml, build.gradle", text: $triggers)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("Status Script (Optional)", comment: "")).font(.caption).foregroundColor(.secondary)
                    TextEditor(text: $statusScript).font(.system(size: 10, design: .monospaced)).frame(height: 60).padding(4).background(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2)))
                }
            }
            HStack {
                Button(NSLocalizedString("Cancel", comment: "")) { isPresented = false }
                Spacer()
                Button(editingRule == nil ? NSLocalizedString("Add Rule", comment: "") : NSLocalizedString("Save Changes", comment: "")) {
                    if let existing = editingRule {
                        if let idx = storage.techDetectionRules.firstIndex(where: { $0.id == existing.id }) {
                            storage.techDetectionRules[idx].name = name
                            storage.techDetectionRules[idx].triggerFiles = triggers
                            storage.techDetectionRules[idx].statusScript = statusScript
                        }
                    } else {
                        storage.techDetectionRules.append(TechDetectionRule(name: name, triggerFiles: triggers, statusScript: statusScript))
                    }
                    storage.saveTechRules()
                    isPresented = false
                }.buttonStyle(.borderedProminent).disabled(name.isEmpty || triggers.isEmpty)
            }
        }.padding(25).frame(width: 350)
        .onAppear {
            if let rule = editingRule {
                name = rule.name
                triggers = rule.triggerFiles
                statusScript = rule.statusScript ?? ""
            }
        }
    }
}

// MARK: - Predictor Rules Management

struct PredictorSettingsContent: View {
    @ObservedObject var storage: StorageManager
    @State private var showingAddPredictor = false
    @State private var editingPredictor: AppContextRule? = nil
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SettingsCard("Prediction Rules") {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(storage.predictorRules) { rule in
                                    PredictorRuleRow(rule: rule, storage: storage) {
                                        editingPredictor = rule
                                    }
                                    if rule != storage.predictorRules.last { Divider().padding(.horizontal, 15) }
                                }
                            }
                        }.frame(maxHeight: .infinity)
                        
                        Divider().padding(.horizontal, 15)
                        HStack {
                            Button(action: { showingAddPredictor = true }) { Label(NSLocalizedString("Add Predictor", comment: ""), systemImage: "plus") }.buttonStyle(.plain).font(.system(size: 11)).foregroundColor(.blue)
                            Spacer()
                            Button(NSLocalizedString("Restore Defaults", comment: "")) { storage.resetPredictorRules() }.buttonStyle(.link).font(.system(size: 11))
                        }.padding(12)
                    }
                }
            }.padding(20)
            
            Divider()
            Text(NSLocalizedString("Boost paths with specific tags when certain apps are active.", comment: ""))
                .font(.system(size: 10)).foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10).padding(.horizontal, 15)
                .background(Color.primary.opacity(0.02))
        }
        .sheet(isPresented: Binding(get: { showingAddPredictor || editingPredictor != nil }, set: { if !$0 { showingAddPredictor = false; editingPredictor = nil } })) {
            PredictorRuleDetailOverlay(storage: storage, isPresented: Binding(get: { showingAddPredictor || editingPredictor != nil }, set: { if !$0 { showingAddPredictor = false; editingPredictor = nil } }), editingRule: editingPredictor)
        }
    }
}

struct PredictorRuleRow: View {
    let rule: AppContextRule; @ObservedObject var storage: StorageManager; let onClick: () -> Void
    @State private var isHovering = false
    
    private var appName: String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleId) {
            return url.deletingPathExtension().lastPathComponent
        }
        
        let commonApps: [String: String] = [
            "com.microsoft.VSCode": "Visual Studio Code",
            "com.todesktop.230313mzl4w4u92": "Cursor",
            "com.sublimetext.4": "Sublime Text",
            "dev.zed.Zed": "Zed",
            "com.jetbrains.intellij": "IntelliJ IDEA",
            "com.apple.TextEdit": "TextEdit",
            "com.googlecode.iterm2": "iTerm2",
            "dev.warp.Warp-Stable": "Warp",
            "com.apple.Terminal": "Terminal",
            "com.github.wez.wezterm": "WezTerm",
            "com.apple.dt.Xcode": "Xcode",
            "com.bohemiancoding.sketch3": "Sketch",
            "com.figma.Desktop": "Figma",
            "com.google.Chrome": "Google Chrome",
            "com.apple.Safari": "Safari",
            "com.apple.finder": "Finder",
            "com.adobe.Photoshop": "Adobe Photoshop",
            "com.adobe.illustrator": "Adobe Illustrator",
            "com.adobe.lightroomCC": "Adobe Lightroom",
            "com.adobe.PremierePro.24": "Adobe Premiere Pro",
            "com.adobe.AfterEffects": "Adobe After Effects"
        ]
        
        return commonApps[rule.bundleId] ?? rule.bundleId
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { newValue in
                    if let idx = storage.predictorRules.firstIndex(where: { $0.id == rule.id }) {
                        storage.predictorRules[idx].isEnabled = newValue
                        storage.savePredictorRules()
                    }
                }
            )).labelsHidden().controlSize(.small)
            
            SmallAppIcon(bundleId: rule.bundleId).frame(width: 18, height: 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(appName).font(.system(size: 13, weight: .medium)).foregroundColor(.primary)
                Text(rule.bundleId).font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                HStack(spacing: 4) {
                    ForEach(rule.targetTags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }
                    Text("(+ \(rule.boost) pts)").font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(action: { 
                storage.predictorRules.removeAll(where: { $0.id == rule.id })
                storage.savePredictorRules()
            }) { Image(systemName: "trash").foregroundColor(.secondary.opacity(0.5)) }.buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(isHovering ? Color.primary.opacity(0.03) : Color.clear)
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onClick)
    }
}

struct PredictorRuleDetailOverlay: View {
    @ObservedObject var storage: StorageManager
    @Binding var isPresented: Bool
    var editingRule: AppContextRule? = nil
    
    @State private var bundleId = ""
    @State private var selectedTags: Set<String> = ["Code"]
    @State private var boost = 500
    @State private var runningApps: [NSRunningApplication] = []
    
    var tagOptions: [String] {
        var base = ["Code", "Design"]
        let custom = storage.techDetectionRules.map { $0.name }
        for c in custom {
            if !base.contains(c) { base.append(c) }
        }
        return base.sorted()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(editingRule == nil ? NSLocalizedString("Add Predictor Rule", comment: "") : NSLocalizedString("Edit Predictor Rule", comment: "")).font(.headline)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("Select Running App", comment: "")).font(.caption).foregroundColor(.secondary)
                    Picker("", selection: $bundleId) {
                        Text(NSLocalizedString("Choose an app...", comment: "")).tag("")
                        ForEach(runningApps, id: \.bundleIdentifier) { app in
                            HStack {
                                if let icon = app.icon {
                                    Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                                }
                                Text(app.localizedName ?? "Unknown").font(.system(size: 11))
                            }.tag(app.bundleIdentifier ?? "")
                        }
                    }.labelsHidden().controlSize(.small)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("Target Tags", comment: "")).font(.caption).foregroundColor(.secondary)
                    // 流式芯片布局：多选
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 65))], spacing: 6) {
                        ForEach(tagOptions, id: \.self) { tag in
                            Button(action: {
                                if selectedTags.contains(tag) {
                                    if selectedTags.count > 1 { selectedTags.remove(tag) }
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }) {
                                Text(tag)
                                    .font(.system(size: 10, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                                    .background(selectedTags.contains(tag) ? Color.blue : Color.primary.opacity(0.05))
                                    .foregroundColor(selectedTags.contains(tag) ? .white : .primary)
                                    .cornerRadius(6)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("Score Boost", comment: "")).font(.caption).foregroundColor(.secondary)
                    HStack {
                        Slider(value: Binding(get: { Double(boost) }, set: { boost = Int($0) }), in: 100...1000, step: 100)
                        Text("+ \(boost)").font(.system(size: 10, design: .monospaced)).frame(width: 40)
                    }
                }
            }
            HStack {
                Button(NSLocalizedString("Cancel", comment: "")) { isPresented = false }
                Spacer()
                Button(editingRule == nil ? NSLocalizedString("Add Rule", comment: "") : NSLocalizedString("Save Changes", comment: "")) {
                    if let existing = editingRule {
                        if let idx = storage.predictorRules.firstIndex(where: { $0.id == existing.id }) {
                            storage.predictorRules[idx].bundleId = bundleId
                            storage.predictorRules[idx].targetTags = Array(selectedTags)
                            storage.predictorRules[idx].boost = boost
                        }
                    } else {
                        storage.predictorRules.append(AppContextRule(bundleId: bundleId, targetTags: Array(selectedTags), boost: boost))
                    }
                    storage.savePredictorRules()
                    isPresented = false
                }.buttonStyle(.borderedProminent).disabled(bundleId.isEmpty || selectedTags.isEmpty)
            }
        }
        .padding(25).frame(width: 380)
        .onAppear {
            if let rule = editingRule {
                bundleId = rule.bundleId
                selectedTags = Set(rule.targetTags)
                boost = rule.boost
            }
            
            self.runningApps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
            
            // 确保如果正在编辑的应用不在运行列表中，也得把它加进去显示出 ID 来
            if !bundleId.isEmpty && !runningApps.contains(where: { $0.bundleIdentifier == bundleId }) {
                // 这里我们不需要真的创建一个 NSRunningApplication，Picker 的 tag 匹配机制会自动处理显示
            }
        }
    }
}
