import SwiftUI

/// A fixed paper texture behind the content, so scrolling never moves the grain.
struct TaleBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    // Keep broader paper variation visible while smoothing away fine fibers.
    private let textureSoftness: CGFloat = 2.5
    private let textureOpacity = 0.14

    // Load the loose SwiftPM resource through AppKit, which also honors @2x sizing.
    private static let paperGrain = Bundle.module.image(forResource: "PaperGrain")

    var body: some View {
        TalePalette(colorScheme: colorScheme).background
            .overlay {
                if colorScheme == .light, let paperGrain = Self.paperGrain {
                    Image(nsImage: paperGrain)
                        .resizable(resizingMode: .tile)
                        .interpolation(.high)
                        .blur(radius: textureSoftness, opaque: true)
                        .blendMode(.multiply)
                        .opacity(textureOpacity)
                }
            }
            .clipped()
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
