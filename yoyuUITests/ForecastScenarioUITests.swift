import XCTest

@MainActor final class ForecastScenarioUITests: XCTestCase {
    func testScenarioEditingAndResults() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--scenario-ui-test"]
        app.launch()
        let edit = app.buttons["forecast.editScenario"]
        XCTAssertTrue(edit.waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["forecast.scenarioTitle"].label, "持续在职")
        edit.tap()
        app.buttons["scenario.mode.temporaryBreak"].tap()
        XCTAssertTrue(app.datePickers["scenario.returnDate"].exists)
        capture(app, "调整情景-三种工作状态")
        app.buttons["取消"].tap()
        XCTAssertEqual(app.staticTexts["forecast.scenarioTitle"].label, "持续在职")
        edit.tap()
        app.buttons["scenario.mode.temporaryBreak"].tap()
        app.buttons["scenario.duration.3"].tap()
        app.swipeUp()
        capture(app, "调整情景-资金与收入")
        app.buttons["scenario.apply"].tap()
        XCTAssertTrue(app.staticTexts["forecast.scenarioTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["forecast.scenarioTitle"].label, "阶段性失业 / gap")
        XCTAssertTrue(app.staticTexts["forecast.runway"].label.contains("2026 年 12 月"))
        capture(app, "阶段性失业-情景与资金结论")
        let expand = app.buttons["forecast.expand"]
        reveal(expand, in: app, top: true)
        capture(app, "阶段性失业-余额趋势")
        XCTAssertTrue(expand.isHittable, app.debugDescription)
        expand.tap()
        XCTAssertTrue(app.buttons["forecast.fullscreen.close"].waitForExistence(timeout: 5))
        capture(app, "情景余额全屏图")
        app.buttons["forecast.fullscreen.close"].tap()
        XCTAssertTrue(app.buttons["forecast.expand"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["每月收支"].tap()
        capture(app, "阶段性失业-每月收支")
        reveal(app.buttons["forecast.details"], in: app)
        XCTAssertTrue(app.staticTexts["forecast.total"].label.contains("59,400"), app.debugDescription)
        app.buttons["forecast.details"].tap()
        XCTAssertTrue(app.navigationBars["逐月明细"].waitForExistence(timeout: 5))
        capture(app, "情景逐月明细")
        app.staticTexts["2026 年 12 月"].tap()
        XCTAssertTrue(app.navigationBars["2026 年 12 月"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "11,000")).firstMatch.exists)
        capture(app, "情景月份计算来源")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        reveal(edit, in: app)
        edit.tap()
        XCTAssertTrue(app.buttons["scenario.mode.temporaryBreak"].isSelected)
        app.buttons["scenario.mode.indefiniteBreak"].tap()
        XCTAssertFalse(app.datePickers["scenario.returnDate"].exists)
        app.buttons["scenario.apply"].tap()
        XCTAssertEqual(app.staticTexts["forecast.scenarioTitle"].label, "长期不再就业")
        capture(app, "长期不再就业")
        edit.tap()
        app.buttons["scenario.mode.employed"].tap()
        app.buttons["scenario.apply"].tap()
        XCTAssertEqual(app.staticTexts["forecast.scenarioTitle"].label, "持续在职")
        XCTAssertEqual(app.staticTexts["forecast.runway"].label, "预测期内资金充足")
    }
    func testChartPresentation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--scenario-demo"]
        app.launch()
        let edit = app.buttons["forecast.editScenario"]
        XCTAssertTrue(edit.waitForExistence(timeout: 15))
        capture(app, "情景首页最终效果")
        let expand = app.buttons["forecast.expand"]
        reveal(expand, in: app, top: true)
        capture(app, "余额图最终效果")
        expand.tap()
        XCTAssertTrue(app.buttons["forecast.fullscreen.close"].waitForExistence(timeout: 5))
        capture(app, "余额图全屏最终效果")
        app.buttons["forecast.fullscreen.close"].tap()
        app.segmentedControls.buttons["每月收支"].tap()
        capture(app, "收支图最终效果")
    }
    func testLinkedSources() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--scenario-demo"]
        app.launch()
        let edit = app.buttons["forecast.editScenario"]
        XCTAssertTrue(edit.waitForExistence(timeout: 15))
        edit.tap()
        reveal(app.textFields["scenario.currentIncome"], in: app)
        XCTAssertFalse(app.textFields["scenario.funds"].exists)
        capture(app, "自动关联计算基础")
        let redemption = app.switches["预测期间赎回理财"]
        reveal(redemption, in: app)
        redemption.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(redemption.value as? String, "1", app.debugDescription)
        XCTAssertTrue(app.datePickers["scenario.redemptionDate"].waitForExistence(timeout: 5), app.debugDescription)
        capture(app, "理财赎回情景")
        app.buttons["scenario.apply"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        reveal(app.switches["预测期间赎回理财"], in: app)
        XCTAssertEqual(app.switches["预测期间赎回理财"].value as? String, "1")
        app.buttons["取消"].tap()
        capture(app, "已保存关联情景")
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, top: Bool = false) {
        for _ in 0..<12 {
            if !element.exists { app.swipeUp(); continue }
            let y = element.frame.midY
            if element.isHittable && y > 120 && y < (top ? 260 : 700) { return }
            let down = y < 120
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.4 : 0.65))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.65 : 0.4)))
        }
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
