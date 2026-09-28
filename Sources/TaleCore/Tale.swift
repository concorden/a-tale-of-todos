import Foundation

public struct Tale: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let name: String

    public init(id: Int64, name: String) {
        self.id = id
        self.name = name
    }

    public static func preparedName(_ name: String) throws -> String {
        let value = EntryText.singleLine(name).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("\0") else { throw DatabaseError.emptyTaleName }
        return value
    }

    public static func nameKey(_ name: String) -> String {
        name.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .precomposedStringWithCanonicalMapping
    }
}

extension Navigation {
    public static func movedTaleID(in tales: [Tale], selection: Int64?, offset: Int) -> Int64? {
        guard !tales.isEmpty else { return nil }
        guard let index = tales.firstIndex(where: { $0.id == selection }) else { return tales.first?.id }
        let next = (index + offset % tales.count + tales.count) % tales.count
        return tales[next].id
    }
}
