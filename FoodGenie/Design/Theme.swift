/// Food Genie's look: black and white with quiet greys, SF Pro, native controls.
/// Every color has a light and a dark value; nothing in the app uses a hue except
/// what the data itself is about (product photos).

import SwiftUI
import UIKit

enum Theme {
    /// Page background.
    static let background = Color(light: 0xFFFFFF, dark: 0x000000)
    /// Cards, inputs, tiles.
    static let surface = Color(light: 0xF5F5F5, dark: 0x111111)
    /// Fills inside cards (image wells, toggles, skeletons).
    static let surfaceStrong = Color(light: 0xEBEBEB, dark: 0x1C1C1C)
    static let border = Color(light: 0xE5E5E5, dark: 0x262626)
    static let text = Color(light: 0x0A0A0A, dark: 0xF5F5F5)
    static let textSecondary = Color(light: 0x6B6B6B, dark: 0xA3A3A3)
    static let textTertiary = Color(light: 0x9E9E9E, dark: 0x6B6B6B)
    /// Text and icons on shapes filled with `text` (primary buttons, the selected store).
    static let inverse = Color(light: 0xFFFFFF, dark: 0x000000)
}

enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 22
}

/// Readable line length on iPad.
let maxContentWidth: CGFloat = 720

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

enum Haptics {
    static func tap() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
