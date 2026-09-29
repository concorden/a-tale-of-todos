import Testing
@testable import TaleCore

struct TaleChoiceTests {
    @Test func singleKeysChooseTheFirstNineTalesInDisplayOrder() {
        for number in 1...9 {
            #expect(TaleChoice.index(for: String(number), count: 12) == number - 1)
        }
    }

    @Test func unavailableTalesAreNotSelected() {
        #expect(TaleChoice.index(for: "1", count: 0) == nil)
        #expect(TaleChoice.index(for: "9", count: 8) == nil)
    }

    @Test func zeroAndMultipleDigitsHaveNoShortcut() {
        for key in ["", "0", "10", "12", "01", "x"] {
            #expect(TaleChoice.index(for: key, count: 12) == nil)
        }
    }
}
