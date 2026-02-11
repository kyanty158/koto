import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - Koto Design System

extension Color {
    // Primary brand colors
    static let kotoAccent = Color(hue: 0.08, saturation: 0.85, brightness: 0.95) // Warm orange
    static let kotoAccentLight = Color(hue: 0.08, saturation: 0.4, brightness: 1.0)
    
    // Surface colors
    static var kotoBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
                : UIColor(red: 0.98, green: 0.97, blue: 0.96, alpha: 1)
        })
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    static var kotoCardBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1)
                : UIColor.white
        })
        #else
        return Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    static var kotoSurfaceBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1)
                : UIColor(red: 0.96, green: 0.95, blue: 0.94, alpha: 1)
        })
        #else
        return Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    // Text colors
    static var kotoPrimaryText: Color {
        #if canImport(UIKit)
        return Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 0.95, alpha: 1)
                : UIColor(white: 0.1, alpha: 1)
        })
        #else
        return Color.primary
        #endif
    }
    
    static var kotoSecondaryText: Color {
        #if canImport(UIKit)
        return Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 0.6, alpha: 1)
                : UIColor(white: 0.45, alpha: 1)
        })
        #else
        return Color.secondary
        #endif
    }
    
    // Semantic colors
    static let kotoSave = Color(hue: 0.35, saturation: 0.7, brightness: 0.75) // Green
    static let kotoDiscard = Color(hue: 0.0, saturation: 0.65, brightness: 0.85) // Red
    static let kotoReminder = Color(hue: 0.08, saturation: 0.8, brightness: 0.95) // Orange
    
    // Gradient helpers
    static var kotoCardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.kotoCardBackground,
                Color.kotoCardBackground.opacity(0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var kotoRailGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.kotoAccent.opacity(0.15),
                Color.kotoAccent.opacity(0.05)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Design Constants

enum KotoDesign {
    static let cornerRadius: CGFloat = 24
    static let cardCornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 12
    
    static let cardHeight: CGFloat = 180
    static let cardHeightWithKeyboard: CGFloat = 140
    
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 16
    
    static let shadowRadius: CGFloat = 16
    static let shadowOpacity: Double = 0.12
    
    static let animationDuration: Double = 0.35
    static let springResponse: Double = 0.45
    static let springDamping: Double = 0.75
}
