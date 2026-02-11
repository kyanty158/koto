import XCTest
@testable import KotoKit

final class InlineTagExtractorTests: XCTestCase {
    func testExtractsUniqueLowercasedTags() {
        let text = "#Todo check #Todo #HOME and #Upcoming\nother text #home"
        let tags = InlineTagExtractor.extract(from: text)
        XCTAssertEqual(tags, ["home", "todo", "upcoming"])
    }

    func testIgnoresInvalidTags() {
        let text = "This is not a tag: # or #! invalid, but #valid-one works"
        let tags = InlineTagExtractor.extract(from: text)
        XCTAssertEqual(tags, ["valid-one"])
    }
}
