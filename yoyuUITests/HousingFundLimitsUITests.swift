import XCTest

@MainActor final class HousingFundLimitsUITests: XCTestCase {
    func testOfficialRangesAndEditing() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--social-limits-ui-test"]
        app.launch()

        let housing = app.buttons["profile.housing"]
        XCTAssertTrue(housing.waitForExistence(timeout: 20))
        housing.tap()
        XCTAssertTrue(app.navigationBars["基数范围"].waitForExistence(timeout: 5))
        let current = app.buttons["housingLimit.nanjing-housing-2026-07"]
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        XCTAssertTrue(current.label.contains("42,400"))
        XCTAssertTrue(current.label.contains("2,660"))
        XCTAssertTrue(current.label.contains("✅"))

        current.tap()
        let upper = app.textFields["housingLimit.upper"]
        XCTAssertTrue(upper.waitForExistence(timeout: 5))
        app.navigationBars["修改公积金基数范围"].buttons["取消"].tap()
        XCTAssertTrue(current.waitForExistence(timeout: 5))
    }
}
