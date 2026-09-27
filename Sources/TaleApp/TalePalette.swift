import SwiftUI

/// Warm paper and ink in light mode, with the native dark surfaces preserved.
struct TalePalette {
    let colorScheme: ColorScheme

    private var isDark: Bool { colorScheme == .dark }

    var background: Color {
        isDark ? Color(nsColor: .windowBackgroundColor) : Color(red: 0.949, green: 0.918, blue: 0.863)
    }

    var surface: Color {
        isDark ? Color(nsColor: .textBackgroundColor) : Color(red: 0.973, green: 0.949, blue: 0.898)
    }

    var editorInk: NSColor {
        isDark ? .labelColor : NSColor(srgbRed: 0.267, green: 0.251, blue: 0.212, alpha: 1)
    }

    var ink: Color { isDark ? .primary : Color(nsColor: editorInk) }

    var secondaryInk: Color {
        isDark ? .secondary : Color(red: 0.380, green: 0.350, blue: 0.300)
    }

    var mutedInk: Color {
        isDark ? Color(nsColor: .tertiaryLabelColor) : Color(red: 0.420, green: 0.390, blue: 0.340)
    }

    var accent: Color {
        isDark ? Color(red: 0.24, green: 0.49, blue: 0.39) : Color(red: 0.365, green: 0.424, blue: 0.310)
    }

    var treeInk: Color {
        isDark ? Color(red: 0.28, green: 0.48, blue: 0.39) : Color(red: 0.435, green: 0.459, blue: 0.341)
    }

    var treeLight: Color {
        isDark ? Color(red: 0.63, green: 0.87, blue: 0.65) : Color(red: 0.435, green: 0.522, blue: 0.322)
    }
}
