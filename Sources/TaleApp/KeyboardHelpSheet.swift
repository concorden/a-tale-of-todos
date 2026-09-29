import SwiftUI

struct KeyboardHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var palette: TalePalette { TalePalette(colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("A little guidance")
                .font(TaleTypography.heading(size: 28))
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 24) {
                section("Around your tale", detail: "When you’re not typing an entry") {
                    shortcut("N", "New note")
                    shortcut("T", "New todo")
                    shortcut("↑ / ↓ · J / K", "Move selection")
                    shortcut("← / →", "Switch tales")
                    shortcut("Enter", "Toggle todo completion")
                    shortcut("C", "Copy selected entry")
                    shortcut("F", "Show unfinished todos / all entries")
                    shortcut("/ · ⌘F", "Find in this tale")
                    shortcut("G", "Go to an entry")
                    shortcut("?", "Show this guidance")
                }

                section("Your tales") {
                    shortcut("Hold ⌘", "Show tales after 0.5 seconds; click to switch")
                    shortcut("⌘1–9", "Switch tales immediately")
                    shortcut("⌘N", "Create a named tale")
                    shortcut("⌘O", "Open a database")
                }

                section("While writing", detail: "Each tale keeps its drafts until you quit or change databases.") {
                    shortcut("Enter", "Add entry")
                    shortcut("Esc", "Keep draft and return")
                }

                section("While finding") {
                    shortcut("↑ / ↓", "Select result")
                    shortcut("Enter", "Jump to entry")
                    shortcut("Esc", "Return to your tale")
                }

                section("After pressing G", detail: "Jumps stay within the current view and do not wrap.") {
                    shortcut("H / T", "Head (newest) / tail (oldest)")
                    shortcut("P / N", "Previous / next in display order")
                    shortcut("F / L", "First (oldest) / last (newest)")
                    shortcut("Then N / T", "Choose note / todo for P, N, F or L")
                    shortcut("Delete", "Back to directions")
                    shortcut("Esc", "Return to your tale")
                }
            }

            Text("esc to return")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(palette.mutedInk)
        }
        .padding(28)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(palette.ink)
        .onExitCommand { dismiss() }
    }

    private func section<Content: View>(_ title: String, detail: String? = nil,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(TaleTypography.heading(size: 20))
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
    }

    private func shortcut(_ keys: String, _ action: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(keys)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.accent)
                .frame(width: 106, alignment: .leading)
            Text(action)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
