import CoreText
import SwiftUI

enum TaleTypography {
    private static let fontAvailable: Bool = {
        guard let url = Bundle.module.url(forResource: "CormorantGaramond", withExtension: "ttf") else { return false }
        return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()

    static func heading(size: CGFloat) -> Font {
        guard fontAvailable else {
            return .system(size: size, weight: .medium, design: .serif)
        }
        // The variable font's PostScript name identifies its light base face;
        // the weight modifier selects the medium instance.
        return .custom("CormorantGaramond-Light", fixedSize: size).weight(.medium)
    }

}
