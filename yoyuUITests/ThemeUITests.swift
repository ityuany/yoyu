import XCTest

@MainActor
final class ThemeUITests: XCTestCase {
    func testLightThemeNavigation() { verifyTheme(dark: false) }
    func testDarkThemeNavigation() { verifyTheme(dark: true) }

    private func verifyTheme(dark: Bool) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--theme-ui-test", "--today-at", "2026-09-22T02:00:00Z"]
        if dark { app.launchArguments.append("--theme-dark") }
        app.launch()
        let mode = dark ? "dark" : "light"
        XCTAssertTrue(app.tabBars.buttons["财富"].waitForExistence(timeout: 20), app.debugDescription)
        capture(app, name: mode + "-today")

        app.tabBars.buttons["财富"].tap()
        XCTAssertTrue(app.staticTexts["已记录资产"].waitForExistence(timeout: 5))
        capture(app, name: mode + "-wealth")
        let cash = app.buttons.containing(.staticText, identifier: "灵活资金").firstMatch
        cash.tap()
        let details = app.buttons["查看资金详情"]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        details.tap()
        XCTAssertTrue(app.navigationBars["现金"].waitForExistence(timeout: 5))
        capture(app, name: mode + "-cash")
        app.buttons["编辑"].tap()
        XCTAssertTrue(app.buttons["取消"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields.firstMatch.exists)
        capture(app, name: mode + "-editor")
        app.buttons["取消"].tap()
        XCTAssertTrue(app.navigationBars["现金"].waitForExistence(timeout: 5))
        app.navigationBars["现金"].buttons.firstMatch.tap()
        XCTAssertTrue(details.waitForExistence(timeout: 5))

        app.tabBars.buttons["分析"].tap()
        XCTAssertTrue(app.buttons["runway.card"].waitForExistence(timeout: 10))
        capture(app, name: mode + "-analysis")
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["个人资料"].waitForExistence(timeout: 5))
        capture(app, name: mode + "-profile")
        app.buttons.containing(.staticText, identifier: "企业履历").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["配色示例企业"].waitForExistence(timeout: 5))
        capture(app, name: mode + "-career")
        app.terminate()
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
