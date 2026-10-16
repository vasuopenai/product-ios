/// Food Genie's look: black and white with quiet greys, SF Pro, native controls.
/// Every color has a light and a dark value. Hues are reserved for meaning: the Nutri-Score
/// grade in its official palette, and green / amber / red on ingredient and allergen chips.

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
    /// Product tiles: white so photos on white blend in; in dark mode the same grey as `surface`.
    static let card = Color(light: 0xFFFFFF, dark: 0x111111)
    /// The soft shadow under a tile in light mode; none in dark mode, where the border does the work.
    static let shadow = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .clear : UIColor(white: 0, alpha: 0.07) })

    // MARK: Meaning

    /// Good news: an ingredient group the product is free of.
    static let good = Color(light: 0x1E8E3E, dark: 0x34C759)
    /// A moderate concern, or a group that may be present.
    static let caution = Color(light: 0xC77700, dark: 0xFFB020)
    /// A serious concern: the worst ingredient groups, and allergens.
    static let bad = Color(light: 0xD93025, dark: 0xFF453A)

    /// The official Nutri-Score palette, dark green (A) to red (E); nil when there's no grade.
    static func nutriscore(_ letter: String?) -> Color? {
        switch letter {
        case "A": Color(uiColor: UIColor(hex: 0x038141))
        case "B": Color(uiColor: UIColor(hex: 0x85BB2F))
        case "C": Color(uiColor: UIColor(hex: 0xFECB02))
        case "D": Color(uiColor: UIColor(hex: 0xEE8100))
        case "E": Color(uiColor: UIColor(hex: 0xE63E11))
        default: nil
        }
    }

    /// The letter on a Nutri-Score badge: dark on the light green and yellow, white elsewhere.
    static func nutriscoreText(_ letter: String?) -> Color {
        letter == "B" || letter == "C" ? Color(uiColor: UIColor(hex: 0x1A1A1A)) : .white
    }
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
