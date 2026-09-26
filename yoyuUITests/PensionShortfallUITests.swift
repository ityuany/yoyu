import XCTest

@MainActor final class PensionShortfallUITests: XCTestCase {
    func testCompanyAndMonthlyEstimate() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--pension-shortfall-ui-test"]
        app.launch()
        let entry = app.buttons["pension.shortfall"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        entry.tap()
        XCTAssertTrue(app.navigationBars["疑似少缴"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "720.00")).firstMatch.exists)
        app.buttons["shortfall.expandTrend"].tap()
        XCTAssertTrue(app.buttons["关闭全屏图表"].waitForExistence(timeout: 5))
        app.buttons["关闭全屏图表"].tap()
        app.swipeUp()
        let longCompany = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "长期企业")).firstMatch
        let shortCompany = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "测试企业")).firstMatch
        XCTAssertTrue(longCompany.waitForExistence(timeout: 5) && shortCompany.exists)
        XCTAssertLessThan(longCompany.frame.minY, shortCompany.frame.minY)
        app.buttons["月均"].tap()
        XCTAssertLessThan(shortCompany.frame.minY, longCompany.frame.minY)
        shortCompany.tap()
        XCTAssertTrue(app.navigationBars["测试企业"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "应缴基数")).firstMatch.exists)
    }
}
