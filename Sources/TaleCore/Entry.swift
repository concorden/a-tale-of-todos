import Foundation

public enum EntryKind: String, CaseIterable, Sendable {
    case note, todo
}

public struct Entry: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let kind: EntryKind
    public let text: String
    public let createdAt: Date
    public let isCompleted: Bool

    public init(id: Int64, kind: EntryKind, text: String, createdAt: Date, isCompleted: Bool) {
        self.id = id
        self.kind = kind
        self.text = text
        self.createdAt = createdAt
        self.isCompleted = isCompleted
    }
}

public enum EntryText {
    public static let limit = 560

    public static func singleLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\u{2028}", with: " ")
            .replacingOccurrences(of: "\u{2029}", with: " ")
    }

    public static func prepared(_ text: String) throws -> String {
        let value = singleLine(text)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DatabaseError.emptyEntry
        }
        guard value.count <= limit else { throw DatabaseError.tooLong }
        return value
    }
}

public enum Navigation {
    public static func movedID(in entries: [Entry], selection: Int64?, offset: Int) -> Int64? {
        guard !entries.isEmpty else { return nil }
        guard let index = entries.firstIndex(where: { $0.id == selection }) else {
            return entries.last?.id
        }
        return entries[min(max(index + offset, 0), entries.count - 1)].id
    }

    public static func replacementID(oldEntries: [Entry], newEntries: [Entry], selection: Int64?) -> Int64? {
        if newEntries.contains(where: { $0.id == selection }) { return selection }
        guard !newEntries.isEmpty else { return nil }
        let oldIndex = oldEntries.firstIndex(where: { $0.id == selection }) ?? newEntries.count - 1
        return newEntries[min(oldIndex, newEntries.count - 1)].id
    }
}
