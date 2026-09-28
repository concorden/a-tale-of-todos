import Foundation

public enum EntrySearch {
    /// Literal matching preserves spaces and punctuation; only case and accents are folded.
    public static func ranges(in text: String, query: String) -> [Range<String.Index>] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        var matches: [Range<String.Index>] = []
        var start = text.startIndex
        while start < text.endIndex,
              let match = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive],
                                     range: start..<text.endIndex), !match.isEmpty {
            matches.append(match)
            start = match.upperBound
        }
        return matches
    }

    /// Entries arrive in timeline order (oldest first).
    public static func results(in entries: [Entry], query: String) -> [Entry] {
        entries.reversed().filter { !ranges(in: $0.text, query: query).isEmpty }
    }
}
