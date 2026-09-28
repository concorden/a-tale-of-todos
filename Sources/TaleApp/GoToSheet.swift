import SwiftUI
import TaleCore

struct GoToSheet: View {
    let model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    private var palette: TalePalette { TalePalette(colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Go to")
                    .font(TaleTypography.heading(size: 28))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(model.goToDirection.map { "g → \($0.rawValue)" } ?? "g")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.mutedInk)
            }
            .padding(.bottom, 18)

            if let direction = model.goToDirection {
                Text(direction.title)
                    .font(TaleTypography.heading(size: 21))
                    .foregroundStyle(palette.secondaryInk)
                    .padding(.bottom, 12)
                option("n", title: "Note") { model.finishGoTo(kind: .note) }
                option("t", title: "Todo") { model.finishGoTo(kind: .todo) }
            } else {
                ForEach(GoToDirection.allCases, id: \.self) { direction in
                    option(direction.rawValue, title: direction.title,
                           detail: direction == .head ? "newest entry" : direction == .tail ? "oldest entry" : nil) {
                        model.chooseGoTo(direction)
                    }
                }
            }

            if let message = model.goToMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.secondaryInk)
                    .padding(.top, 14)
            }

            HStack {
                if model.goToDirection != nil {
                    Button("⌫ back", action: model.goToBack)
                    Spacer()
                }
                Button("esc to return") { model.isGoingTo = false }
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(palette.mutedInk)
            .padding(.top, 20)
        }
        .padding(28)
        .frame(width: 340)
        .foregroundStyle(palette.ink)
        .onExitCommand { model.isGoingTo = false }
    }

    private func option(_ key: String, title: String, detail: String? = nil,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(key)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.accent)
                    .frame(width: 26, height: 26)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 5))
                Text(title).font(.system(size: 14))
                Spacer()
                if let detail {
                    Text(detail).font(.system(size: 11)).foregroundStyle(palette.mutedInk)
                }
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)\(detail.map { ", \($0)" } ?? ""), \(key)")
    }
}
