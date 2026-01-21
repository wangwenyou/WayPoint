import SwiftUI

struct ColorTheme {
    static let raycastGray = Color(hex: "F2F3F5")
    
    struct Background {
        static func adaptive(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(white: 0.15) : Color.white
        }
    }
    
    struct Text {
        static let primary = Color.primary
        static let secondary = Color.secondary
        static let tertiary = Color.secondary.opacity(0.7)
        static let quaternary = Color.secondary.opacity(0.4)
        
        static func mediumContrast(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(white: 0.7) : Color(white: 0.4)
        }
        
        static func lowContrast(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(white: 0.4) : Color(white: 0.7)
        }
    }
    
    struct Accent {
        static let blue = Color.blue
        static let softBlue = Color.blue.opacity(0.7)
        static let orange = Color.orange
        static let softOrange = Color.orange.opacity(0.7)
        static let green = Color.green
        static let softGreen = Color.green.opacity(0.7)
        static let yellow = Color.yellow
        static let purple = Color.purple
    }
    
    struct Border {
        static func primary(_ scheme: ColorScheme) -> Color {
            Color.primary.opacity(scheme == .dark ? 0.2 : 0.1)
        }
        static func secondary(_ scheme: ColorScheme) -> Color {
            Color.primary.opacity(0.05)
        }
    }
    
    struct Interactive {
        static let hover = Color.primary.opacity(0.08)
    }
    
    static var backgroundColor: Color { Color(NSColor.windowBackgroundColor) }
    static var secondaryBackgroundColor: Color { Color.primary.opacity(0.05) }
    static var accentColor: Color { Color.blue }
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