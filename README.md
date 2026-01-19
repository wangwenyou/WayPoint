# WayPoint 🧭

[中文文档](README_CN.md)

**WayPoint** is a powerful macOS utility designed to revolutionize how you navigate your file system. It acts as a smart, central hub for your file paths, allowing you to jump between folders, open projects in your favorite tools, and even inject paths into system file dialogs with lightning speed.

> ⚡️ **Extreme Efficiency:** Open any target folder with as few as 3 keystrokes: `⌥ Space` (Invoke) -> `Search` -> `Enter` (Open).

![WayPoint Main UI](dialog.png)

## 🚀 Key Features

*   **⚡️ Instant Access:** Trigger WayPoint globally with a hotkey (Default: `Option + Space`) to immediately start searching your path history.
*   **🔍 Fuzzy Search:** Intelligent search algorithm that supports fuzzy matching. It prioritizes results based on exact matches, prefixes, usage frequency, and more.
*   **📂 Finder Sync:** Automatically tracks the path of your currently active Finder window. No more copying and pasting paths manually; WayPoint knows where you are. *(Requires Accessibility Permissions)*
*   **📋 Clipboard Monitoring:** Smartly detects when you copy a file or a path string to your clipboard and automatically adds it to your history.
*   **🛠 Powerful Actions:**
    *   **Open:** Reveal in Finder.
    *   **Terminal:** Open directory in iTerm2 (or Terminal.app).
    *   **Editor:** Open in Visual Studio Code (or default editor).
    *   **Copy:** Copy path to clipboard.
    *   **💉 Inject:** Magic feature! Instantly navigate to a selected path within any system "Open" or "Save" dialog.
*   **⭐️ Favorites & History:** Pin frequently used paths to your "Favorites" tab for permanent access, while keeping track of your recent workflow in the "Recent" tab.
*   **🤖 System Search:** Seamlessly falls back to system-wide Spotlight search (`mdfind`) when a local match isn't found.

## 🛠 Installation & Build

### Prerequisites
*   macOS (macOS 13+ recommended)
*   Xcode 14+ (for building from source)

### Building from Source

1.  Clone the repository:
    ```bash
    git clone https://github.com/your-username/WayPoint.git
    cd WayPoint
    ```
2.  Open the project in Xcode:
    ```bash
    open WayPoint.xcodeproj
    ```
3.  Build and Run (⌘R).

## 📖 Usage Guide

### First Launch & Permissions
Upon first launch, WayPoint will request **Accessibility Permissions**. This is crucial for:
1.  Monitoring the active Finder window path.
2.  Injecting paths into file dialogs.

Please grant these permissions in `System Settings -> Privacy & Security -> Accessibility`.

### Basic Interaction
*   **Toggle Window:** Press `Option + Space` (default).
*   **Navigation:** Use `Up/Down` arrow keys to navigate results.
*   **Select:** Press `Enter` to execute the default action (Open in Finder).
*   **Tabs:** Switch between "Recent" and "Favorites".

### Actions
When an item is selected, you can perform various actions (shortcuts may vary based on key bindings, check UI for tooltips):
*   **Open in Finder:** Default Action
*   **Open in Terminal:** Specific command/button
*   **Open in Editor:** Specific command/button
*   **Inject to Dialog:** Use when an Open/Save dialog is active to jump to that folder.

## ⚙️ Configuration
WayPoint stores its configuration and history locally.
*   **Hotkeys:** Can be customized (logic exists in `HotKeyManager`).
*   **Exclusions:** You can exclude specific paths from appearing in your history.

## 🏗 Technologies
*   **SwiftUI:** Modern, declarative UI.
*   **Combine:** Reactive state management.
*   **AppKit & Carbon:** Low-level system integration for hotkeys and window management.
*   **Accessibility API:** For deep system integration (Finder tracking, Dialog injection).

## 🤝 Contribution
Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License
[MIT License](LICENSE) (or your preferred license)