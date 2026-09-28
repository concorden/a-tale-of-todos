public enum GoToDirection: String, CaseIterable, Sendable {
    case head = "h", tail = "t", previous = "p", next = "n", first = "f", last = "l"

    public var title: String {
        switch self {
        case .head: "Head"
        case .tail: "Tail"
        case .previous: "Previous"
        case .next: "Next"
        case .first: "First"
        case .last: "Last"
        }
    }

    public var needsKind: Bool { self != .head && self != .tail }
}

extension Navigation {
    /// Entries are in display order (newest first). Relative jumps never wrap.
    /// First and last refer to creation order: oldest and newest matching entries.
    /// A missing destination returns nil so callers can keep the selection intact.
    public static func destinationID(in entries: [Entry], selection: Int64?,
                                     direction: GoToDirection, kind: EntryKind? = nil) -> Int64? {
        switch direction {
        case .head: return entries.first?.id
        case .tail: return entries.last?.id
        case .first: return entries.last { $0.kind == kind }?.id
        case .last: return entries.first { $0.kind == kind }?.id
        case .previous, .next:
            guard let index = entries.firstIndex(where: { $0.id == selection }) else {
                return entries.first { $0.kind == kind }?.id
            }
            if direction == .previous {
                return entries[..<index].last { $0.kind == kind }?.id
            }
            return entries[(index + 1)...].first { $0.kind == kind }?.id
        }
    }
}
