import XCTest

@MainActor
final class AnalysisCardsUITests: XCTestCase {
    func testLightCards() { verify(dark: false) }
    func testDarkCards() { verify(dark: true) }

    func testLargeLightCards() { verify(dark: false, large: true) }
    func testLargeDarkCards() { verify(dark: true, large: true) }

    private func verify(dark: Bool, large: Bool = false) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--theme-ui-test", "--today-at", "2026-09-22T02:00:00Z"]
        if large { app.launchArguments.append("--analysis-large-values") }
        if dark { app.launchArguments.append("--theme-dark") }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["分析"].waitForExistence(timeout: 20))
        app.tabBars.buttons["分析"].tap()
        let runway = app.buttons["runway.card"]
        let pension = app.buttons["analysis.pension"]
        let housing = app.buttons["analysis.housing"]
        XCTAssertTrue(runway.waitForExistence(timeout: 10))
        XCTAssertTrue(pension.exists)
        XCTAssertTrue(housing.exists)
        XCTAssertTrue(app.staticTexts["runway.result"].waitForExistence(timeout: 20))
        let range = app.segmentedControls["analysis.chartRange"]
        XCTAssertTrue(range.waitForExistence(timeout: 5))
        range.buttons["1 年"].tap()
        XCTAssertTrue(range.buttons["1 年"].isSelected)
        app.buttons["analysis.expand"].tap()
        XCTAssertTrue(app.buttons["runway.closeChart"].waitForExistence(timeout: 5))
        let coveredTab = app.tabBars.buttons["分析"]
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == false"), object: coveredTab)], timeout: 5) == .completed, app.debugDescription)
        XCTAssertTrue(app.segmentedControls["runway.fullscreenRange"].buttons["1 年"].isSelected)
        capture(app, name: dark ? "fullscreen-dark" : "fullscreen-light")
        app.buttons["runway.closeChart"].tap()
        XCTAssertTrue(range.waitForExistence(timeout: 5))
        XCTAssertTrue(range.buttons["1 年"].isSelected)
        range.buttons["5 年"].tap()
        let prefix = large ? "analysis-large" : "analysis"
        capture(app, name: prefix + (dark ? "-dark" : "-light"))
        app.swipeUp()
        if large {
            for identifier in ["analysis.pension.total", "analysis.housing.total", "analysis.pension.shortfall", "analysis.housing.shortfall"] {
                let metric = app.otherElements[identifier]
                XCTAssertTrue(metric.exists)
                let amount = Double(metric.label.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) ?? 0
                XCTAssertGreaterThan(amount, 1_000_000, metric.label)
                XCTAssertFalse(metric.label.contains("万元"), "无障碍读数应保留精确金额")
                XCTAssertTrue(app.frame.contains(metric.frame), "大额指标必须完整入镜")
            }
        }
        capture(app, name: prefix + (dark ? "-dark-contributions" : "-light-contributions"))
        XCTAssertFalse(app.buttons["analysis.pension.expand"].exists)
        XCTAssertFalse(app.buttons["analysis.housing.expand"].exists)
        pension.tap()
        XCTAssertTrue(app.navigationBars["养老保险分析"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["分析"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(pension.waitForExistence(timeout: 5))
        if !housing.isHittable { app.swipeUp() }
        housing.tap()
        XCTAssertTrue(app.navigationBars["住房公积金分析"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(housing.waitForExistence(timeout: 5))
        app.swipeDown()
        if !runway.isHittable { app.swipeDown() }
        runway.tap()
        XCTAssertTrue(app.navigationBars["生存时长"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["个人资料"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profile.pension"].exists)
        XCTAssertFalse(app.buttons["profile.housing"].exists)
        app.terminate()
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
