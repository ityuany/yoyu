import XCTest

@MainActor final class ForecastUITests: XCTestCase {
    func testForecastRangesAndMonthNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--forecast-ui-test"]
        app.launch()
        XCTAssertTrue(app.buttons["forecast.editScenario"].waitForExistence(timeout: 15))
        for (range, amount) in [("未来 12 个月", "54,000"), ("3 年", "138,000"), ("5 年", "222,000")] {
            let picker = app.segmentedControls.buttons[range]
            reveal(picker, in: app)
            picker.tap()
            let total = app.staticTexts["forecast.total"]
            reveal(total, in: app)
            XCTAssertTrue(total.label.contains(amount), total.label)
        }
        reveal(app.buttons["forecast.details"], in: app)
        app.buttons["forecast.details"].tap()
        XCTAssertTrue(app.navigationBars["逐月明细"].waitForExistence(timeout: 5))
        app.staticTexts["2026 年 12 月"].tap()
        XCTAssertTrue(app.navigationBars["2026 年 12 月"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "11,000")).firstMatch.exists)
    }
    func testFullscreenPreservesRange() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--forecast-ui-test"]
        app.launch()
        XCTAssertTrue(app.buttons["forecast.editScenario"].waitForExistence(timeout: 15))
        for range in ["未来 12 个月", "3 年", "5 年"] {
            let picker = app.segmentedControls.buttons[range]
            reveal(picker, in: app)
            picker.tap()
            let expand = app.buttons["forecast.expand"]
            reveal(expand, in: app)
            expand.tap()
            let close = app.buttons["forecast.fullscreen.close"]
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["forecast.fullscreen.range"].label.contains(range))
            close.tap()
            XCTAssertTrue(app.buttons["forecast.expand"].waitForExistence(timeout: 5))
            XCTAssertTrue(picker.isSelected)
        }
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            let y = element.frame.midY
            if element.isHittable && y > 120 && y < 700 { return }
            let down = y < 120
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.4 : 0.65))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.65 : 0.4)))
        }
    }
}
