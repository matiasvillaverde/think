import Database
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    private enum HexConstants {
        static let maxChannel: CGFloat = 255
        static let maxChannelU64: UInt64 = 255
        static let nibbleMultiplier: UInt64 = 17
        static let nibbleMask: UInt64 = 0xF
        static let byteMask: UInt64 = 0xFF
        static let shift24: UInt64 = 24
        static let shift16: UInt64 = 16
        static let shift8: UInt64 = 8
        static let shift4: UInt64 = 4
        static let shortRGBLength: Int = 3
        static let rgbLength: Int = 6
        static let argbLength: Int = 8
    }

    /// Parses user-provided hex into a SwiftUI `Color`.
    ///
    /// This is intentionally centralized in UIComponents so the rest of the app never constructs
    /// ad-hoc colors directly.
    static func userProvided(hex: String) -> Color? {
        Color(hexString: hex)
    }

    /// Converts a `Color` to a hex string in `#RRGGBB` form when possible.
    ///
    /// Useful for persisting user-selected colors back into `tintColorHex`.
    func toHex() -> String? {
        #if canImport(UIKit)
        let uiColor: UIColor = UIColor(self)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        return String(
            format: "#%02X%02X%02X",
            Int(red * HexConstants.maxChannel),
            Int(green * HexConstants.maxChannel),
            Int(blue * HexConstants.maxChannel)
        )
        #elseif canImport(AppKit)
        let nsColor: NSColor = NSColor(self)
        guard let rgbColor: NSColor = nsColor.usingColorSpace(.sRGB) else {
            return nil
        }

        return String(
            format: "#%02X%02X%02X",
            Int(rgbColor.redComponent * HexConstants.maxChannel),
            Int(rgbColor.greenComponent * HexConstants.maxChannel),
            Int(rgbColor.blueComponent * HexConstants.maxChannel)
        )
        #else
        return nil
        #endif
    }

    private init?(hexString: String) {
        let trimmed: String = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0

        guard Scanner(string: trimmed).scanHexInt64(&int) else {
            return nil
        }

        let alpha: UInt64
        let red: UInt64
        let green: UInt64
        let blue: UInt64
        switch trimmed.count {
        case HexConstants.shortRGBLength: // RGB (12-bit)
            (alpha, red, green, blue) = (
                HexConstants.maxChannelU64,
                (int >> HexConstants.shift8) * HexConstants.nibbleMultiplier,
                (int >> HexConstants.shift4 & HexConstants.nibbleMask)
                    * HexConstants.nibbleMultiplier,
                (int & HexConstants.nibbleMask) * HexConstants.nibbleMultiplier
            )

        case HexConstants.rgbLength: // RGB (24-bit)
            (alpha, red, green, blue) = (
                HexConstants.maxChannelU64,
                int >> HexConstants.shift16,
                int >> HexConstants.shift8 & HexConstants.byteMask,
                int & HexConstants.byteMask
            )

        case HexConstants.argbLength: // ARGB (32-bit)
            (alpha, red, green, blue) = (
                int >> HexConstants.shift24,
                int >> HexConstants.shift16 & HexConstants.byteMask,
                int >> HexConstants.shift8 & HexConstants.byteMask,
                int & HexConstants.byteMask
            )

        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(red) / Double(HexConstants.maxChannelU64),
            green: Double(green) / Double(HexConstants.maxChannelU64),
            blue: Double(blue) / Double(HexConstants.maxChannelU64),
            opacity: Double(alpha) / Double(HexConstants.maxChannelU64)
        )
    }
}

// MARK: - Personality Tint Color

extension Personality {
    /// UI-only tint color derived from the persisted `tintColorHex`.
    ///
    /// Database stores tint as hex for portability; UIComponents owns the conversion to `Color`.
    public var tintColor: Color {
        if let tintColorHex, let color = Color.userProvided(hex: tintColorHex) {
            return color
        }

        return .accentColor
    }
}
