import SwiftUI

private typealias ViewState<Value> = SwiftUI.State<Value>

struct TreePulse {
    let id = UUID()
    let leftStrand = Int.random(in: 0..<3)
    let rightStrand = Int.random(in: 0..<3)

    func strand(on side: Int) -> Int {
        side == 0 ? leftStrand : rightStrand
    }
}

/// A fixed drawing: the irregularities stay in place when content or window size changes.
private struct TreeStrand: Shape {
    let index: Int
    let side: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let height = max(1, rect.height)
        let phase = CGFloat(index) * 2.094 + CGFloat(side) * 0.65

        func point(_ t: CGFloat) -> CGPoint {
            let twist = sin(t * .pi * 4.3 + phase) * 0.21
            let drift = sin(t * .pi * 2.1 + 0.8 + CGFloat(side)) * 0.065
            let irregularity = sin(t * .pi * 9 + phase * 1.7) * 0.022
            let x = 0.5 + twist + drift + irregularity
            return CGPoint(x: rect.minX + rect.width * (side == 0 ? x : 1 - x),
                           y: rect.minY + t * height)
        }

        // Cubic segments keep the long strands smooth, even at large window sizes.
        let segments = 36
        path.move(to: point(0))
        for segment in 0..<segments {
            let t0 = CGFloat(segment) / CGFloat(segments)
            let t1 = CGFloat(segment + 1) / CGFloat(segments)
            let a = point(t0)
            let b = point(t1)
            let epsilon: CGFloat = 0.0001
            let da = point(t0 + epsilon)
            let db = point(t1 - epsilon)
            let factor = (t1 - t0) / (3 * epsilon)
            path.addCurve(to: b,
                          control1: CGPoint(x: a.x + (da.x - a.x) * factor,
                                            y: a.y + (da.y - a.y) * factor),
                          control2: CGPoint(x: b.x + (db.x - b.x) * factor,
                                            y: b.y + (db.y - b.y) * factor))
        }

        // A few short, tapered-looking offshoots, staggered between strands.
        for branch in 0..<3 {
            let t = 0.14 + CGFloat(branch) * 0.29 + CGFloat(index) * 0.047 + CGFloat(side) * 0.018
            let root = point(t)
            let direction: CGFloat = (branch + index + side).isMultiple(of: 2) ? -1 : 1
            let reach = rect.width * (0.13 + CGFloat(branch % 2) * 0.045) * direction
            let rise = min(25, height * 0.045)
            path.move(to: root)
            path.addCurve(to: CGPoint(x: root.x + reach, y: root.y - rise),
                          control1: CGPoint(x: root.x + reach * 0.65, y: root.y - rise * 0.2),
                          control2: CGPoint(x: root.x + reach * 0.55, y: root.y - rise * 0.8))
        }
        return path
    }
}

struct TaleTree: View {
    let side: Int
    let progress: CGFloat
    let canScroll: Bool
    let hasEntries: Bool
    let pulse: TreePulse?
    let navigate: (CGFloat) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @ViewState private var pulseAmount: CGFloat = 0
    @ViewState private var hovering = false

    private var ink: Color { Color(red: 0.28, green: 0.48, blue: 0.39) }
    private var light: Color {
        colorScheme == .dark
            ? Color(red: 0.63, green: 0.87, blue: 0.65)
            : Color(red: 0.22, green: 0.59, blue: 0.38)
    }

    var body: some View {
        GeometryReader { geometry in
            let position = progress * max(1, geometry.size.height)
            ZStack {
                ForEach(0..<3) { index in
                    let strand = TreeStrand(index: index, side: side)
                    let amount = pulse?.strand(on: side) == index ? pulseAmount : 0
                    ZStack {
                        strand.stroke(ink.opacity(colorScheme == .dark ? 0.48 : 0.30),
                                      style: StrokeStyle(lineWidth: index == 1 ? 1.6 : 1.15, lineCap: .round))
                        strand.stroke(light, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .blur(radius: 5)
                            .opacity(amount * 0.75)
                        strand.stroke(light, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                            .opacity(amount)
                    }
                    .scaleEffect(x: 1 + (reduceMotion ? 0 : amount * 0.045), y: 1)
                }

                if hasEntries {
                    // A horizontal pool of light catches only the branches it crosses.
                    // There is no track or thumb drawn over the tree.
                    ZStack {
                        strands(lineWidth: 5).blur(radius: 5).opacity(0.85)
                        strands(lineWidth: 2)
                    }
                    .foregroundStyle(light)
                    .mask(alignment: .top) {
                        LinearGradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.3), location: 0.25),
                            .init(color: .white, location: 0.46),
                            .init(color: .white, location: 0.54),
                            .init(color: .white.opacity(0.3), location: 0.75),
                            .init(color: .clear, location: 1)
                        ], startPoint: .top, endPoint: .bottom)
                        .frame(height: 48)
                        .offset(y: position - 24)
                    }
                }
            }
            .opacity(hovering && canScroll ? 1 : 0.85)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard canScroll else { return }
                navigate(min(1, max(0, location.y / max(1, geometry.size.height))))
            }
            .onHover { hovering = $0 }
        }
        .help(canScroll ? "Click to move through your tale" : "Your whole tale is in view")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(side == 0 ? "Left" : "Right") tale navigation")
        .accessibilityValue(!hasEntries ? "Empty tale" : canScroll ? "\(Int((progress * 100).rounded())) percent" : "Entire tale visible")
        .accessibilityAdjustableAction { direction in
            guard canScroll else { return }
            switch direction {
            case .increment: navigate(min(1, progress + 0.1))
            case .decrement: navigate(max(0, progress - 0.1))
            @unknown default: break
            }
        }
        .task(id: pulse?.id) {
            pulseAmount = 0
            guard pulse != nil else { return }
            withAnimation(.easeInOut(duration: 0.2)) { pulseAmount = 1 }
            do { try await Task.sleep(for: .milliseconds(220)) }
            catch { return }
            withAnimation(.easeOut(duration: 1.6)) { pulseAmount = 0 }
        }
    }

    private func strands(lineWidth: CGFloat) -> some View {
        ZStack {
            ForEach(0..<3) { index in
                TreeStrand(index: index, side: side)
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
        }
    }
}
