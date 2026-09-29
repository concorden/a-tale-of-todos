import CoreGraphics

extension Navigation {
    /// Retain focus within the middle half of the viewport. When it leaves that
    /// band, choose the nearest visible entry, using actual (possibly wrapped) rows.
    public static func focusFollowingScroll(in frames: [Int64: CGRect], selection: Int64?,
                                             viewport: CGRect) -> Int64? {
        guard viewport.height > 0 else { return nil }
        let band = viewport.insetBy(dx: 0, dy: viewport.height * 0.25)
        var target = viewport.midY
        if let selection, let frame = frames[selection] {
            if (band.minY...band.maxY).contains(frame.midY)
                || (frame.minY <= viewport.midY && frame.maxY >= viewport.midY) {
                return selection
            }
            target = min(band.maxY, max(band.minY, frame.midY))
        }
        return frames.filter { $0.value.maxY > viewport.minY && $0.value.minY < viewport.maxY }
            .min {
                let a = abs($0.value.midY - target)
                let b = abs($1.value.midY - target)
                return a == b ? $0.key < $1.key : a < b
            }?.key
    }
}
