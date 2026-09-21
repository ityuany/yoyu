import XCTest

@MainActor final class ForecastUITests: XCTestCase {
    func testForecastRangesAndMonthNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--forecast-ui-test"]
        app.launch()
        let total = app.staticTexts["forecast.total"]
        XCTAssertTrue(total.waitForExistence(timeout: 15))
        XCTAssertTrue(total.label.contains("54,000"), total.label)
        capture(app, "预测首页")
        app.segmentedControls.buttons["3 年"].tap()
        XCTAssertTrue(total.label.contains("138,000"), total.label)
        app.segmentedControls.buttons["5 年"].tap()
        XCTAssertTrue(total.label.contains("222,000"), total.label)
        capture(app, "五年预测")
        app.segmentedControls.buttons["未来 12 个月"].tap()
        app.swipeUp()
        capture(app, "预测变化与说明")
        let details = app.buttons["forecast.details"]
        XCTAssertTrue(details.waitForExistence(timeout: 5), app.debugDescription)
        details.tap()
        XCTAssertTrue(app.navigationBars["逐月明细"].waitForExistence(timeout: 5))
        app.staticTexts["2026 年 12 月"].tap()
        XCTAssertTrue(app.navigationBars["预计支出"].waitForExistence(timeout: 5))
        capture(app, "明细定位检查")
        XCTAssertTrue(app.staticTexts["2026 年 12 月"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "11,000")).firstMatch.exists)
        capture(app, "十二月支出来源")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["逐月明细"].waitForExistence(timeout: 5))
    }
    func testFullscreenPreservesRange() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--forecast-ui-test"]
        app.launch()
        XCTAssertTrue(app.buttons["forecast.expand"].waitForExistence(timeout: 15))
        for range in ["未来 12 个月", "3 年", "5 年"] {
            app.segmentedControls.buttons[range].tap()
            let total = app.staticTexts["forecast.total"].label
            app.buttons["forecast.expand"].tap()
            let close = app.buttons["forecast.fullscreen.close"]
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            let label = app.staticTexts["forecast.fullscreen.range"]
            XCTAssertTrue(label.label.contains(range), label.label)
            capture(app, "横向全屏-" + range)
            close.tap()
            XCTAssertTrue(app.buttons["forecast.expand"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.segmentedControls.buttons[range].isSelected)
            XCTAssertEqual(app.staticTexts["forecast.total"].label, total)
        }
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
