import XCTest

@MainActor final class HousingShortfallUITests: XCTestCase {
    func testCompanyOverviewGroupsPaymentAndShortfall() {
        let app = XCUIApplication()
        app.launchArguments = ["--housing-shortfall-ui-test"]
        app.launch()
        let entry = app.buttons["housing.companyOverview"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        entry.tap()
        XCTAssertTrue(app.navigationBars["住房公积金"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["累计缴纳"].exists)
        XCTAssertTrue(app.buttons["housing.monthlyPayments"].exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "疑似少缴")).firstMatch.exists)
        app.buttons["housing.monthlyPayments"].tap()
        XCTAssertTrue(app.navigationBars["逐月缴纳"].waitForExistence(timeout: 5))
    }

    func testMonthlyPaymentComparison() {
        let app = XCUIApplication()
        app.launchArguments = ["--housing-shortfall-ui-test"]
        app.launch()
        let entry = app.buttons["housing.monthlyPayments"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        entry.tap()
        XCTAssertTrue(app.navigationBars["逐月缴纳"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["低于预期"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["符合预期"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["2024 年 3 月"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["¥ 960.00"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["参考 ¥ 1,200.00"].firstMatch.exists)
    }

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
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "应缴基数")).firstMatch.exists, app.debugDescription)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "当月工资")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["少缴月份"].exists)
        XCTAssertTrue(app.staticTexts["2024 年 2 月"].exists)
        XCTAssertFalse(app.staticTexts["2024 年 3 月"].exists)
        let details = XCTAttachment(screenshot: app.screenshot())
        details.name = "公积金逐月对照"
        details.lifetime = .keepAlways
        add(details)
    }
}
