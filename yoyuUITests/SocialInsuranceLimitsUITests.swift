import XCTest

@MainActor final class SocialInsuranceLimitsUITests: XCTestCase {
    func testSeedAddEditDelete() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--social-limits-ui-test"]
        app.launch()

        let menu = app.buttons["profile.pension"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        menu.tap()
        let baseRange = app.buttons["pension.baseRange"]
        XCTAssertTrue(baseRange.waitForExistence(timeout: 5))
        baseRange.tap()
        XCTAssertTrue(app.navigationBars["基数范围"].waitForExistence(timeout: 5))
        let newest = app.buttons["socialLimit.nanjing-2026-01"]
        let older = app.buttons["socialLimit.nanjing-2025-01"]
        XCTAssertTrue(newest.exists)
        XCTAssertTrue(older.exists)
        XCTAssertLessThan(newest.frame.minY, older.frame.minY)

        app.buttons["socialLimit.add"].tap()
        let lower = app.textFields["socialLimit.lower"]
        lower.tap()
        lower.typeText("5000")
        let upper = app.textFields["socialLimit.upper"]
        upper.tap()
        upper.typeText("25000")
        app.navigationBars["新增社保上下限"].buttons["保存"].tap()

        XCTAssertFalse(app.searchFields.firstMatch.exists)
        let testRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "25,000")).firstMatch
        XCTAssertTrue(testRow.waitForExistence(timeout: 5))
        testRow.tap()
        let editedUpper = app.textFields["socialLimit.upper"]
        XCTAssertTrue(editedUpper.waitForExistence(timeout: 5))
        editedUpper.tap()
        editedUpper.press(forDuration: 1.2)
        let selectAll = app.menuItems["Select All"]
        XCTAssertTrue(selectAll.waitForExistence(timeout: 3))
        selectAll.tap()
        editedUpper.typeText("26000")
        app.navigationBars["修改社保上下限"].buttons["保存"].tap()
        let editedRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "26,000")).firstMatch
        XCTAssertTrue(editedRow.waitForExistence(timeout: 5))

        editedRow.tap()
        app.buttons["删除这条标准"].tap()
        app.buttons["删除"].tap()
        XCTAssertFalse(editedRow.waitForExistence(timeout: 2))
    }
}
