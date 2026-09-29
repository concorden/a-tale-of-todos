import SwiftUI
import TaleCore

/// Standard margin marks shared by entries and the composer.
struct TaleEntryMark: View {
    let kind: EntryKind
    var isCompleted = false
    @Environment(\.colorScheme) private var colorScheme

    private var palette: TalePalette { TalePalette(colorScheme: colorScheme) }

    var body: some View {
        Group {
            if kind == .todo {
                Image(systemName: isCompleted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(isCompleted ? palette.accent.opacity(0.65) : palette.secondaryInk)
            } else {
                Circle()
                    .fill(palette.secondaryInk)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 20, height: 21)
        .accessibilityHidden(true)
    }
}
