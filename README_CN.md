# WayPoint 🧭

> 🚀 **macOS 上的 Autojump GUI 版本，解决频繁目录切换的痛点。**

[English README](README.md)

在日常开发和工作中，我们每天都要和无数的目录打交道。在不同的项目、文档、配置文件夹之间频繁切换，往往花费了我们大量无效的时间。

在命令行终端，`autojump` 或 `z` 这样的工具已经完美解决了这个问题 —— 你只需要记住目录名的一部分，就能瞬间跳转。但在 GUI 环境（Finder、编辑器、打开/保存对话框）中，我们却不得不一次次地手动点击、逐层寻找。

**WayPoint** 的诞生正是为了填补这一空白。它将 `autojump` 的核心理念带入了图形界面，并与你的命令行习惯无缝互通。

> ⚡️ **极致效率：** 最快只需按 3 次键盘，即可打开目标文件夹：`⌥ Space` (唤起) -> `输入搜索` -> `回车` (打开)。

![WayPoint 主界面](dialog.png)

## ✨ 核心特性

*   **⚡️ 秒级唤起:** 全局快捷键（默认 `Option + Space`）瞬间呼出搜索框，甚至比 Spotlight 更快专注于路径导航。
*   **🤝 Autojump 数据互通:** WayPoint **直接兼容并导入** `autojump` 的历史数据。如果你是命令行的重度用户，你的所有跳转权重都会被完美继承，无需从零开始训练。
*   **🔍 智能模糊匹配:** 采用加权算法，根据**访问频率**、**最近访问时间**、**名称匹配度**综合排序。输入 `doc` 可能会定位到 `~/Documents`，输入 `proj` 可能直达 `~/Source/Projects`。
*   **📂 Finder 自动同步:** 总是忘记刚才在这个 Finder 窗口打开的是哪个目录？WayPoint 会通过 Accessibility API 自动监听当前激活的 Finder 路径，无需手动复制。
*   **📋 剪贴板智能感知:** 当你复制了一个文件，或者复制了一串路径文本，WayPoint 会自动识别并将其加入历史记录。
*   **🛠 高效操作流:**
    *   **Open:** 在 Finder 中揭示。
    *   **Terminal:** 一键在 iTerm2 或 Terminal 中打开当前路径。
    *   **Editor:** 使用 VS Code 打开项目。
    *   **Inject (注入):** **杀手级功能！** 当你在 Photoshop、Word 或任何软件中面对“打开/保存”文件对话框时，呼出 WayPoint 选择路径，它会将目标路径直接“注入”到对话框中并跳转。
*   **🤖 系统级回退:** 本地历史找不到？WayPoint 会自动回退调用系统级 Spotlight (`mdfind`) 搜索，确保你不会空手而归。

## 🛠 安装与构建

### 系统要求
*   macOS 13+ (推荐)
*   Xcode 14+ (仅源码构建需要)

### 源码构建

1.  克隆仓库:
    ```bash
    git clone https://github.com/your-username/WayPoint.git
    cd WayPoint
    ```
2.  在 Xcode 中打开:
    ```bash
    open WayPoint.xcodeproj
    ```
3.  编译运行 (⌘R)。

## 📖 使用指南

### 首次启动与权限
为了实现“Finder 路径监听”和“对话框注入”功能，WayPoint 首次启动时会请求 **辅助功能 (Accessibility)** 权限。

请前往 `系统设置 -> 隐私与安全性 -> 辅助功能` 中授权 WayPoint。

### 常用快捷键
*   **唤起/隐藏:** `Option + Space`
*   **导航:** `↑` / `↓` 选择结果
*   **确认:** `Enter` (执行默认操作，通常是打开 Finder)
*   **切换标签:** 在“最近”和“收藏”之间切换。

### 操作 (Actions)
选中结果后，你可以执行多种操作（具体快捷键请参考 UI 提示）：
*   **打开 (Finder):** 默认操作
*   **终端 (Terminal):** 直接进入命令行
*   **编辑器 (Editor):** 使用代码编辑器打开
*   **复制路径 (Copy):** 复制绝对路径到剪贴板
*   **注入 (Inject):** 当“打开/保存”窗口处于前台时使用，直接跳转目录。

## ⚙️ 配置
WayPoint 的数据存储在本地。
*   **Autojump 数据:** 启动时会自动尝试从 `~/.local/share/autojump/autojump.txt` 或 `~/Library/autojump/autojump.txt` 导入数据。

## 🏗 技术栈
*   **SwiftUI:** 现代化的声明式 UI。
*   **Combine:** 响应式数据流处理。
*   **AppKit & Carbon:** 底层系统集成（全局热键、窗口管理）。
*   **Accessibility API:** 深度系统集成（路径嗅探、按键模拟）。

## 🤝 贡献
欢迎提交 Issue 或 Pull Request！

## 📄 许可证
[MIT License](LICENSE)
