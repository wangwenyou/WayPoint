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
                HStack {
                    Text(NSLocalizedString("Settings", comment: "")).font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 25).padding(.top, 25).padding(.bottom, 15).background(Color.primary.opacity(0.02))
                
                TabView(selection: $selectedTab) {
                    SettingsTabWrapper {
                        GeneralSettingsContent(keysString: $keysString, isRecordingGlobal: $isRecordingGlobal, languageManager: languageManager, onUpdateShortcut: updateShortcut)
                    }.tabItem { Label(NSLocalizedString("General", comment: ""), systemImage: "gearshape") }.tag(0)
                    
                    SettingsTabWrapper {
                        ShortcutsSettingsContent(shortcutManager: shortcutManager, storage: storage, editorPresets: editorPresets, terminalPresets: terminalPresets, recordingAction: $recordingAction, onUpdate: updateActionShortcut)
                    }.tabItem { Label(NSLocalizedString("Shortcuts", comment: ""), systemImage: "keyboard") }.tag(1)
                    
                    SettingsTabWrapper {
                        ExclusionsSettingsContent(storage: storage)
                    }.tabItem { Label(NSLocalizedString("Exclusions", comment: ""), systemImage: "eye.slash") }.tag(2)
                    
                    SettingsTabWrapper {
                        ContextRulesSettingsContent(vm: vm, storage: storage, editingRule: $editingRule)
                    }.tabItem { Label(NSLocalizedString("Rules", comment: ""), systemImage: "bolt.horizontal.circle") }.tag(3)
                    
                    SettingsTabWrapper { InsightsView() }.tabItem { Label(NSLocalizedString("Insights", comment: ""), systemImage: "chart.pie") }.tag(4)
                    
                    SettingsTabWrapper { AboutSettingsView(updateChecker: updateChecker) }.tabItem { Label(NSLocalizedString("About", comment: ""), systemImage: "info.circle") }.tag(5)
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

// MARK: - Components

struct SettingsTabWrapper<Content: View>: View {
    let content: Content; init(@ViewBuilder content: () -> Content) { self.content = content() }; var body: some View { content.padding(20) }
}

struct SettingsCard<Content: View>: View {
    let title: LocalizedStringKey; let content: Content
    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary).padding(.leading, 4)
            VStack(spacing: 0) { content }.background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04))).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.06), lineWidth: 1))
        }.padding(.bottom, 12)
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
    @Binding var keysString: String; @Binding var isRecordingGlobal: Bool; @ObservedObject var languageManager: LanguageManager; var onUpdateShortcut: (NSEvent) -> Void
    var body: some View {
        ScrollView {
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
            }
            SettingsCard("Global Shortcut") {
                VStack(spacing: 8) {
                    Button(action: { isRecordingGlobal = true }) { Text(isRecordingGlobal ? "..." : keysString).frame(maxWidth: .infinity).padding(.vertical, 4) }.buttonStyle(.bordered).background(ShortcutRecorderView(isRecording: $isRecordingGlobal, onRecord: onUpdateShortcut))
                    Text(NSLocalizedString("Main Hotkey to toggle WayPoint", comment: "")).font(.system(size: 10)).foregroundColor(.secondary)
                }.padding(12)
            }
        }
    }
}

struct ShortcutsSettingsContent: View {
    @ObservedObject var shortcutManager: LocalShortcutManager; @ObservedObject var storage: StorageManager; let editorPresets: [AppOption]; let terminalPresets: [AppOption]; @Binding var recordingAction: LocalAction?; var onUpdate: (LocalAction, NSEvent) -> Void
    var body: some View {
        ScrollView {
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
        }
    }
    enum AppType { case editor, terminal }
    private func chooseApp(for type: AppType) {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.application]; panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier {
                let appName = url.deletingPathExtension().lastPathComponent
                DispatchQueue.main.async { if type == .editor { storage.customEditorName = appName; storage.preferredEditor = bundleId } else { storage.customTerminalName = appName; storage.preferredTerminal = bundleId } }
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
        VStack(alignment: .leading) {
            SettingsCard("Excluded Paths") {
                if storage.excludedPaths.isEmpty {
                    Text(NSLocalizedString("No excluded paths", comment: "")).italic().font(.system(size: 11)).foregroundColor(.secondary).padding(15)
                } else {
                    let sorted = Array(storage.excludedPaths).sorted()
                    VStack(spacing: 0) {
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
            }
            Spacer()
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
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(storage.contextRules) { rule in
                        RuleRow(rule: rule, storage: storage, onClick: { editingRule = rule })
                    }
                    Button(action: { vm.showingAddRule = true }) { Label(NSLocalizedString("Add New Rule", comment: ""), systemImage: "plus").frame(maxWidth: .infinity).padding(.vertical, 8) }.buttonStyle(.bordered).padding(.top, 8)
                    Button(NSLocalizedString("Restore Defaults", comment: "")) { storage.resetRulesToDefaults() }.buttonStyle(.link).font(.system(size: 11)).padding(.top, 4)
                }.padding(.bottom, 20)
            }
            Text(NSLocalizedString("WayPoint will show quick action buttons when these files are detected.", comment: "")).font(.system(size: 10)).foregroundColor(.secondary).padding(.top, 10)
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
                let prefix = NSLocalizedString("If folder contains", comment: "")
                Text("\(prefix): \(rule.triggerFile)").font(.system(size: 10)).foregroundColor(.secondary)
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