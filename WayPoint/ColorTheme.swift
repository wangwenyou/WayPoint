import SwiftUI

struct ColorTheme {
    static let raycastGray = Color(hex: "F2F3F5")
    
    struct Background {
        static func adaptive(_ scheme: ColorScheme) -> Color {
            // 暗黑模式使用更加深邃的配色，明亮模式维持纯净的 Raycast 灰
            scheme == .dark ? Color(white: 0.11) : raycastGray
        }
        
        static func secondary(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
        }
    }
    
    struct Text {
        static let primary = Color.primary
        static let secondary = Color.secondary
        static func tertiary(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.4)
        }
        
        static func mediumContrast(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(white: 0.75) : Color(white: 0.35)
        }
        
        static func lowContrast(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(white: 0.45) : Color(white: 0.65)
        }
    }
    
    struct Accent {
        static let blue = Color.blue
        static let softBlue = Color.blue.opacity(0.7)
        static let orange = Color.orange
        static let yellow = Color.yellow
        static let green = Color.green
        static let purple = Color.purple
    }
    
    struct Border {
        static func primary(_ scheme: ColorScheme) -> Color {
            // 暗黑模式下边框更细微
            Color.primary.opacity(scheme == .dark ? 0.12 : 0.08)
        }
        static func secondary(_ scheme: ColorScheme) -> Color {
            Color.primary.opacity(scheme == .dark ? 0.06 : 0.04)
        }
    }
    
    struct Interactive {
        static func hover(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}