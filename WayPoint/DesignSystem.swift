import SwiftUI

struct DesignSystem {
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    
    struct Typography {
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 16, weight: .semibold)
        static let callout = Font.system(size: 14, weight: .regular)
        static let caption = Font.system(size: 11, weight: .regular)
        static let resultTitle = Font.system(size: 14, weight: .medium)
        static let resultSubtitle = Font.system(size: 11, weight: .regular)
    }
    
    struct CornerRadius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
        static let window: CGFloat = 12
    }
    
    struct Animation {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.75)
        static let springQuick = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.8)
    }
}

// 扩展方便在 View 中使用
extension View {
    func cardStyle(_ colorScheme: ColorScheme) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
