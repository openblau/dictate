@testable import Dictate
import XCTest

final class CustomWordsTests: XCTestCase {
    private func replacer(_ pairs: [(String, String)]) -> CustomWordReplacer {
        CustomWordReplacer(words: pairs.map { CustomWord(heard: $0.0, written: $0.1) })
    }

    func testReplacesHeardPhraseWithWrittenSpelling() {
        let replacer = replacer([("block swap", "Bloxwap")])
        XCTAssertEqual(replacer.apply(to: "I work at block swap now."), "I work at Bloxwap now.")
    }

    func testMatchingIgnoresCaseAndTheGapsBetweenWords() {
        let replacer = replacer([("block swap", "Bloxwap")])
        XCTAssertEqual(replacer.apply(to: "Block Swap"), "Bloxwap")
        XCTAssertEqual(replacer.apply(to: "blockswap"), "Bloxwap")
        XCTAssertEqual(replacer.apply(to: "BLOCK-SWAP"), "Bloxwap")
        XCTAssertEqual(replacer.apply(to: "block  swap"), "Bloxwap")
    }

    func testOnlyWholeWordsMatch() {
        let replacer = replacer([("block swap", "Bloxwap")])
        XCTAssertEqual(replacer.apply(to: "roadblock swap"), "roadblock swap")
        XCTAssertEqual(replacer.apply(to: "block swapping"), "block swapping")
        XCTAssertEqual(replacer.apply(to: "block swap's roadmap"), "Bloxwap's roadmap")
        XCTAssertEqual(replacer.apply(to: "(block swap)"), "(Bloxwap)")
    }

    func testEveryOccurrenceIsReplaced() {
        let replacer = replacer([("block swap", "Bloxwap")])
        XCTAssertEqual(replacer.apply(to: "Block swap, block swap and blockswap."), "Bloxwap, Bloxwap and Bloxwap.")
    }

    func testLongerPhrasesWinOverShorterOnes() {
        let replacer = replacer([("swap", "Swap"), ("block swap", "Bloxwap")])
        XCTAssertEqual(replacer.apply(to: "block swap and swap"), "Bloxwap and Swap")
    }

    func testSpecialCharactersAreTakenLiterally() {
        let replacer = replacer([("c plus plus", "C++"), ("cost (usd)", "$1 \\0")])
        XCTAssertEqual(replacer.apply(to: "I write c plus plus."), "I write C++.")
        XCTAssertEqual(replacer.apply(to: "the cost (usd) field"), "the $1 \\0 field")
    }

    func testIncompleteRulesAreIgnored() {
        let replacer = replacer([("", "Bloxwap"), ("block swap", "  "), ("   ", "x")])
        XCTAssertTrue(replacer.isEmpty)
        XCTAssertEqual(replacer.apply(to: "block swap"), "block swap")
    }

    func testWrittenTextIsTrimmed() {
        let replacer = replacer([(" block swap ", " Bloxwap ")])
        XCTAssertEqual(replacer.apply(to: "at block swap today"), "at Bloxwap today")
    }

    func testPreferenceRoundTripsThroughDefaults() throws {
        let suiteName = "CustomWordsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(CustomWordPreference.load(from: defaults), [])
        let words = [CustomWord(heard: "block swap", written: "Bloxwap")]
        CustomWordPreference.save(words, to: defaults)
        XCTAssertEqual(CustomWordPreference.load(from: defaults), words)
    }

    func testUnreadablePreferenceLoadsAsEmpty() throws {
        let suiteName = "CustomWordsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(Data("not json".utf8), forKey: CustomWordPreference.defaultsKey)
        XCTAssertEqual(CustomWordPreference.load(from: defaults), [])
    }

    @MainActor
    func testStorePersistsEveryEdit() throws {
        let suiteName = "CustomWordsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = CustomWordStore(defaults: defaults)
        store.add()
        store.words[0].heard = "block swap"
        store.words[0].written = "Bloxwap"
        XCTAssertEqual(CustomWordPreference.load(from: defaults), store.words)

        store.remove(store.words[0])
        XCTAssertEqual(CustomWordPreference.load(from: defaults), [])
    }
}
