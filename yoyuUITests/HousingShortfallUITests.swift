import XCTest

@MainActor final class HousingShortfallUITests: XCTestCase {
    func testEstimateAndMonthlyDetails() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--housing-shortfall-ui-test"]
        app.launch()
        let entry = app.buttons["housing.shortfall"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        entry.tap()
        XCTAssertTrue(app.navigationBars["疑似少缴"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "480.00")).firstMatch.exists)
        let overview = XCTAttachment(screenshot: app.screenshot())
        overview.name = "公积金疑似少缴概览"
        overview.lifetime = .keepAlways
        add(overview)
        app.buttons["全屏查看年度变化"].tap()
        XCTAssertTrue(app.buttons["关闭全屏图表"].waitForExistence(timeout: 5))
        app.buttons["关闭全屏图表"].tap()
        app.swipeUp()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "测试企业")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["测试企业"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "已录基数")).firstMatch.exists, app.debugDescription)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "当月工资")).firstMatch.exists)
        let details = XCTAttachment(screenshot: app.screenshot())
        details.name = "公积金逐月对照"
        details.lifetime = .keepAlways
        add(details)
    }
}
