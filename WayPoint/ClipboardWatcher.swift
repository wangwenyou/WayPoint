import AppKit
import Combine

class ClipboardWatcher: ObservableObject {
    private var timer: Timer?
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    
    init() {
        self.lastChangeCount = pasteboard.changeCount
        startWatching()
    }
    
    func startWatching() {
        // 每 1 秒检查一次剪贴板
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }
    
    private func checkPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        // 1. 优先尝试读取文件 URL (Finder 复制文件)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            for url in urls {
                if url.isFileURL {
                    let path = url.path
                    print("📂 Detected file path from clipboard: \(path)")
                    StorageManager.shared.addOrUpdate(path: path, source: .clipboard)
                }
            }
            return // 如果找到了文件，就不再当作字符串处理
        }
        
        // 2. 尝试读取由于 Cmd+Option+C 复制的路径文本
        if let copiedString = pasteboard.string(forType: .string) {
            // Trim whitespace and newlines
            let path = copiedString.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 检查是否以 / 开头（简单的路径判断）
            // 也可以使用 FileManager 判断是否存在
            if path.hasPrefix("/") {
                // 二次验证：确保确实是存在的路径，避免误判普通文本
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
                    print("📝 Detected path string from clipboard: \(path)")
                    StorageManager.shared.addOrUpdate(path: path, source: .clipboard)
                }
            }
        }
    }
}
