# WayPoint 🧭

[中文文档](README_CN.md)

**WayPoint** is a powerful macOS utility designed to revolutionize how you navigate your file system. It acts as a smart, central hub for your file paths, allowing you to jump between folders, open projects in your favorite tools, and even inject paths into system file dialogs with lightning speed.

> ⚡️ **Extreme Efficiency:** Open any target folder with as few as 3 keystrokes: `⌥ Space` (Invoke) -> `Search` -> `Enter` (Open).

![WayPoint Main UI](dialog.png)

## 🚀 Key Features

*   **⚡️ Instant Access:** Trigger WayPoint globally with a hotkey (Default: `Option + Space`) to immediately start searching your path history.
*   **🔍 Fuzzy Search:** Intelligent search algorithm that supports fuzzy matching. It prioritizes results based on exact matches, prefixes, usage frequency, and more.
*   **📂 Finder Sync:** Automatically tracks the path of your currently active Finder window. WayPoint knows where you are. *(Requires Accessibility Permissions)*
*   **📋 Clipboard Monitoring:** Smartly detects when you copy a file or a path string to your clipboard and automatically adds it to your history.
*   **🏗 Open Architecture (v1.3.0+):**
    *   **Customizable UI:** Toggle visibility for Tags, Scores, and Status Info. Make it as minimalist or as detailed as you like.
    *   **Programmable Toolbar:** Enable, disable, and reorder standard actions via drag-and-drop to match your unique muscle memory.
    *   **Tunable Scoring:** Adjust the weights for Frequency, Recency, and Prediction. Set custom path multipliers to boost or demote specific folders.
    *   **Portable Config:** Export and import your rules and preferences as a JSON file.
*   **🛠 Powerful Actions:**
    *   **Open:** Reveal in Finder.
    *   **Terminal:** Open directory in iTerm2, Warp, or Terminal.app.
    *   **Editor:** Open in VS Code, Cursor, Zed, or your preferred IDE.
    *   **Copy:** Copy path to clipboard.
    *   **💉 Inject:** Magic feature! Instantly navigate to a selected path within any system "Open" or "Save" dialog.
    *   **Context Rules:** Automatically shows "npm start", "Install Deps", "Docker Up", etc., based on folder contents.
*   **⭐️ Favorites & History:** Pin frequently used paths to your "Favorites" tab for permanent access.
*   **🤖 System Search:** Seamlessly falls back to Spotlight search (`mdfind`) when a local match isn't found.

## 🧩 Navigation Tabs

WayPoint provides three distinct views to help you find the right path at the right time:

*   **🎯 Focus (Smart):** The default view. It uses an intelligent algorithm that considers visit frequency, recency, and context prediction (e.g., boosting project paths related to your currently running apps). It's designed to surface the paths you most likely need *right now*.
*   **⭐ Favorites (Manual):** User-curated list. This tab is persistent and keeps the folders you've manually "starred" easily accessible, regardless of how often you visit them.
*   **👣 Footprints (Chronological):** A simple, time-ordered log of your recent activity. It's the best way to trace back where you've been in the last few minutes or hours.


## 🛠 Installation & Build

### Prerequisites
*   macOS 13+ recommended.
*   Xcode 15+ (for building from source).

### Building from Source

1.  Clone the repository:
    ```bash
    git clone https://github.com/wangwenyou/WayPoint.git
    cd WayPoint
    ```
2.  Open the project in Xcode:
    ```bash
    open WayPoint.xcodeproj
    ```
3.  Build and Run (⌘R).

## 📖 Usage Guide

### First Launch & Permissions
WayPoint requires **Accessibility Permissions** for monitoring Finder and injecting paths. Grant them in `System Settings -> Privacy & Security -> Accessibility`.

### Basic Interaction
*   **Toggle Window:** `Option + Space` (default).
*   **Navigation:** `Up/Down` arrows.
*   **Select:** `Enter` for default action.
*   **Actions:** Hover over a result to see the floating toolbar or use CMD + [Key] shortcuts.

## ⚙️ Configuration
*   **Interface:** Hide tags or scores for a cleaner look.
*   **Scoring:** Tweak the algorithm in the "Scoring" tab. Use "Path Multipliers" to demote folders like `~/Desktop` by setting them to `0.5x`.
*   **Rules:** Create your own terminal commands triggered by specific files.

## 🏗 Technologies
*   **SwiftUI:** Modern, declarative UI.
*   **Combine:** Reactive state management.
*   **AppKit & Carbon:** Low-level system integration.
*   **Accessibility API:** Finder tracking and dialog injection.

## 🤝 Contribution
Contributions are welcome! Feel free to submit a Pull Request.

## 📄 License
[MIT License](LICENSE)
