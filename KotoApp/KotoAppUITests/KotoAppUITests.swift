import XCTest

final class KotoAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTabsExist() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["書く"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["見る"].exists)
        XCTAssertTrue(app.tabBars.buttons["設定"].exists)
    }

    func testListTabMenuExists() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["見る"].tap()
        XCTAssertTrue(app.navigationBars["メモ"].waitForExistence(timeout: 5))

        let menuButton = app.buttons["memoListToolbarMenu"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(app.buttons["選択"].waitForExistence(timeout: 3))
    }
}
