/// Only the first nine tales have keyboard shortcuts; every tale remains clickable.
public enum TaleChoice {
    public static func index(for key: String, count: Int) -> Int? {
        guard key.count == 1, let digit = key.first, ("1"..."9").contains(digit),
              let number = Int(key), number <= count else { return nil }
        return number - 1
    }
}
