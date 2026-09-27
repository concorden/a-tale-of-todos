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

/// A fixed ink drawing: bends and offshoots keep their identity across redraws and resizing.
private struct TreeStrand: Shape {
    let index: Int
    let side: Int
    var lineWidth: CGFloat = 1

    // Unequal, hand-placed bends keep the stems from reading as a repeating braid.
    private static let bends: [[CGFloat]] = [
        [0.40, 0.32, 0.45, 0.67, 0.61, 0.39, 0.29, 0.38, 0.60, 0.65, 0.49, 0.35, 0.43],
        [0.55, 0.64, 0.60, 0.40, 0.34, 0.47, 0.65, 0.59, 0.40, 0.31, 0.38, 0.57, 0.61],
        [0.65, 0.53, 0.35, 0.39, 0.53, 0.65, 0.54, 0.33, 0.36, 0.49, 0.59, 0.50, 0.32]
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let height = max(1, rect.height)
        let phase = CGFloat(index) * 1.73 + CGFloat(side) * 2.31

        // Small deterministic variations, independent of Swift's randomized Hasher.
        func variation(_ seed: Int) -> CGFloat {
            let value = sin(CGFloat(seed + index * 137 + side * 271) * 12.9898) * 43758.5453
            return value - floor(value)
        }

        func point(_ t: CGFloat) -> CGPoint {
            let stations = Self.bends[index]
            let position = min(1, max(0, side == 0 ? t : 1 - t)) * CGFloat(stations.count - 1)
            let section = min(stations.count - 2, Int(position))
            let f = position - CGFloat(section)
            let a = stations[max(0, section - 1)]
            let b = stations[section]
            let c = stations[section + 1]
            let d = stations[min(stations.count - 1, section + 2)]
            let bend = 0.5 * ((2 * b) + (-a + c) * f
                + (2 * a - 5 * b + 4 * c - d) * f * f
                + (-a + 3 * b - 3 * c + d) * f * f * f)
            let drift = sin(t * .pi * 3.7 + phase) * 0.035
            let grain = sin(t * .pi * 19 + phase) * 0.008
            let x = bend + drift + grain
            return CGPoint(x: rect.minX + rect.width * (side == 0 ? x : 1 - x),
                           y: rect.minY + t * height)
        }

        // Filled ribbons allow the ink to swell at joints and taper to fine twig tips.
        func ribbon(samples: Int, width: (CGFloat) -> CGFloat, curve: (CGFloat) -> CGPoint) {
            var left: [CGPoint] = []
            var right: [CGPoint] = []
            for step in 0...samples {
                let t = CGFloat(step) / CGFloat(samples)
                let p = curve(t)
                let before = curve(max(0, t - 0.001))
                let after = curve(min(1, t + 0.001))
                let dx = after.x - before.x
                let dy = after.y - before.y
                let length = max(0.001, hypot(dx, dy))
                let radius = width(t) * lineWidth * 0.5
                left.append(CGPoint(x: p.x - dy / length * radius, y: p.y + dx / length * radius))
                right.append(CGPoint(x: p.x + dy / length * radius, y: p.y - dx / length * radius))
            }
            path.move(to: left[0])
            for p in left.dropFirst() { path.addLine(to: p) }
            for p in right.reversed() { path.addLine(to: p) }
            path.closeSubpath()
        }

        func cubic(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint, _ t: CGFloat) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u*u*u*a.x + 3*u*u*t*b.x + 3*u*t*t*c.x + t*t*t*d.x,
                           y: u*u*u*a.y + 3*u*u*t*b.y + 3*u*t*t*c.y + t*t*t*d.y)
        }

        ribbon(samples: 180, width: { t in
            let body: CGFloat = index == 1 ? 1.48 : 1.05
            return body * (0.88 + 0.14 * sin(t * .pi * 7.3 + phase)
                          + 0.07 * sin(t * .pi * 23 + phase))
        }, curve: point)

        for branch in 0..<8 {
            let t = 0.055 + (CGFloat(branch) + variation(branch * 11) * 0.58) * 0.112
            let root = point(t)
            let outward: CGFloat = root.x < rect.midX ? -1 : 1
            let direction = variation(branch * 11 + 1) < 0.78 ? outward : -outward
            let short = variation(branch * 11 + 2) < 0.42
            let reach = rect.width * (short ? 0.065 : 0.12 + variation(branch * 11 + 3) * 0.12)
            let rise = min(height * 0.06, rect.width * (short ? 0.13 : 0.24 + variation(branch * 11 + 4) * 0.24))
            let upward: CGFloat = variation(branch * 11 + 5) < 0.16 ? 1 : -1
            let tip = CGPoint(x: min(rect.maxX - rect.width * 0.08,
                                     max(rect.minX + rect.width * 0.08, root.x + direction * reach)),
                              y: root.y + upward * rise)
            let nearby = point(t + upward * 0.012)
            let c1 = CGPoint(x: root.x + (nearby.x - root.x) * 0.55 + direction * reach * 0.12,
                             y: root.y + upward * rise * 0.38)
            let c2 = CGPoint(x: tip.x - direction * reach * (short ? 0.15 : 0.42),
                             y: tip.y - upward * rise * (0.12 + variation(branch * 11 + 6) * 0.48))
            ribbon(samples: 20, width: { u in
                (short ? 1.05 : 1.25) * pow(1 - u, 0.8) + 0.08
            }, curve: { cubic(root, c1, c2, tip, $0) })

            // Occasional split tips, with plenty of bare stem between them.
            if !short && (branch + index + side).isMultiple(of: 3) {
                let joint = cubic(root, c1, c2, tip, 0.56)
                let forkTip = CGPoint(x: joint.x + direction * reach * 0.48,
                                      y: joint.y + upward * rise * 0.12)
                ribbon(samples: 12, width: { 0.65 * (1 - $0) + 0.06 }, curve: {
                    cubic(joint,
                          CGPoint(x: joint.x + direction * reach * 0.16, y: joint.y + upward * rise * 0.14),
                          CGPoint(x: forkTip.x - direction * reach * 0.1, y: forkTip.y),
                          forkTip, $0)
                })
            }
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

    private var palette: TalePalette { TalePalette(colorScheme: colorScheme) }
    private var ink: Color { palette.treeInk }
    private var light: Color { palette.treeLight }

    var body: some View {
        GeometryReader { geometry in
            let position = progress * max(1, geometry.size.height)
            ZStack {
                ForEach(0..<3) { index in
                    let strand = TreeStrand(index: index, side: side)
                    let amount = pulse?.strand(on: side) == index ? pulseAmount : 0
                    ZStack {
                        strand.fill(ink.opacity(colorScheme == .dark ? 0.48 : 0.30))
                        TreeStrand(index: index, side: side, lineWidth: 3)
                            .fill(light)
                            .blur(radius: 5)
                            .opacity(amount * 0.75)
                        strand.fill(light)
                            .opacity(amount)
                    }
                    .scaleEffect(x: 1 + (reduceMotion ? 0 : amount * 0.045), y: 1)
                }

                if hasEntries {
                    // A horizontal pool of light catches only the branches it crosses.
                    // There is no track or thumb drawn over the tree.
                    ZStack {
                        strands(lineWidth: 5).blur(radius: 5).opacity(0.85)
                        strands(lineWidth: 1.25)
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
                TreeStrand(index: index, side: side, lineWidth: lineWidth)
                    .fill()
            }
        }
    }
}
