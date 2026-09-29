import SwiftUI

struct TaleSwitcher: View {
    let model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    private var palette: TalePalette { TalePalette(colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your tales")
                    .font(TaleTypography.heading(size: 28))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("⌘")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(palette.mutedInk)
            }

            if model.tales.isEmpty {
                Text("Every tale starts somewhere.")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.secondaryInk)
            } else {
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(Array(model.tales.enumerated()), id: \.element.id) { index, tale in
                            option(index < 9 ? String(index + 1) : nil, title: tale.name,
                                   current: model.activeTaleID == tale.id) {
                                model.chooseTale(tale.id)
                            }
                        }
                    }
                }
                .frame(height: min(CGFloat(model.tales.count) * 43, 258))
            }

            option("n", title: "New tale") { model.beginNewTale() }

            VStack(alignment: .leading, spacing: 6) {
                Text("Hold ⌘ and press 1–9 to switch immediately.")
                Text("Click any tale · esc or release ⌘ to cancel")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(palette.mutedInk)
        }
        .padding(28)
        .frame(width: 400)
        .foregroundStyle(palette.ink)
        .background { TaleBackground() }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(palette.mutedInk.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        .accessibilityAddTraits(.isModal)
    }

    private func option(_ key: String?, title: String,
                        current: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(key ?? "")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.accent)
                    .frame(minWidth: 28, minHeight: 28)
                    .background(key == nil ? .clear : palette.surface, in: RoundedRectangle(cornerRadius: 5))
                Text(title)
                    .font(.system(size: 14))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if current {
                    Text("current")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.mutedInk)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(key.map { "\($0), " } ?? "")\(title)\(current ? ", current tale" : "")")
    }
}
