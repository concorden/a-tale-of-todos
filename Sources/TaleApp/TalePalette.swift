import SwiftUI

/// Parchment and ink by day; warm earth, ivory, and moss by night.
struct TalePalette {
    let colorScheme: ColorScheme

    private var isDark: Bool { colorScheme == .dark }

    var background: Color {
        isDark ? Color(red: 0.145, green: 0.137, blue: 0.114) : Color(red: 0.949, green: 0.918, blue: 0.863)
    }

    var surface: Color {
        isDark ? Color(red: 0.192, green: 0.180, blue: 0.149) : Color(red: 0.973, green: 0.949, blue: 0.898)
    }

    var editorInk: NSColor {
        isDark ? NSColor(srgbRed: 0.882, green: 0.835, blue: 0.737, alpha: 1)
            : NSColor(srgbRed: 0.267, green: 0.251, blue: 0.212, alpha: 1)
    }

    var ink: Color { Color(nsColor: editorInk) }

    var secondaryInk: Color {
        isDark ? Color(red: 0.725, green: 0.682, blue: 0.584) : Color(red: 0.380, green: 0.350, blue: 0.300)
    }

    var mutedInk: Color {
        isDark ? Color(red: 0.650, green: 0.610, blue: 0.524) : Color(red: 0.420, green: 0.390, blue: 0.340)
    }

    var accent: Color {
        isDark ? Color(red: 0.647, green: 0.667, blue: 0.478) : Color(red: 0.365, green: 0.424, blue: 0.310)
    }

    var selection: Color { accent.opacity(isDark ? 0.12 : 0.07) }

    var treeInk: Color {
        isDark ? Color(red: 0.573, green: 0.584, blue: 0.424) : Color(red: 0.435, green: 0.459, blue: 0.341)
    }

    var treeLight: Color {
        isDark ? Color(red: 0.784, green: 0.745, blue: 0.557) : Color(red: 0.435, green: 0.522, blue: 0.322)
    }
}
