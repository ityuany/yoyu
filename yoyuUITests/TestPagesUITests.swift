import XCTest

@MainActor
final class TestPagesUITests: XCTestCase {
    func testLightCatalogueAndAllScenes() {
        verify(dark: false, ids: [
            "theme-light-regular", "theme-dark-regular", "theme-light-large", "theme-dark-large",
            "runwayDemo", "employmentPayday", "severance", "expense", "expenseDedupe",
            "financialExport", "socialLimits", "pensionShortfall", "housingShortfall", "mortgage"
        ])
    }

    func testDarkCatalogueAndReturn() {
        verify(dark: true, ids: ["theme-dark-regular", "expense", "pensionShortfall"])
    }

    private func verify(dark: Bool, ids: [String]) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--theme-ui-test"] + (dark ? ["--theme-dark"] : [])
        app.launch()
        app.tabBars.buttons["我的"].tap()
        let entry = app.buttons["profile.testPages"]
        if !entry.isHittable { app.swipeUp() }
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.navigationBars["测试页面"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["我的"].exists)
        capture(app, name: dark ? "测试目录-深色" : "测试目录-浅色")
        app.swipeUp()
        capture(app, name: dark ? "测试目录下部-深色" : "测试目录下部-浅色")
        app.swipeDown()

        for id in ids {
            let row = app.buttons["testPages.\(id)"]
            for _ in 0..<4 where !row.isHittable { app.swipeUp() }
            XCTAssertTrue(row.isHittable, id)
            row.tap()
            let close = app.buttons["testPages.close"]
            XCTAssertTrue(close.waitForExistence(timeout: 10), id)
            // 以现有业务内容出现为准，避免仅验证外层关闭栏。
            switch id {
            case let id where id.hasPrefix("theme"):
                XCTAssertTrue(app.tabBars.buttons["分析"].waitForExistence(timeout: 10))
                let visibleTabs = app.tabBars.buttons.matching(identifier: "分析")
                    .allElementsBoundByIndex.filter { $0.isHittable }
                XCTAssertEqual(visibleTabs.count, 1)
                visibleTabs.first?.tap()
                XCTAssertTrue(app.buttons["runway.card"].waitForExistence(timeout: 10))
            case "expense", "expenseDedupe":
                XCTAssertTrue(app.staticTexts["生活费"].waitForExistence(timeout: 10))
            case "financialExport":
                XCTAssertTrue(app.buttons["profile.financialExport"].waitForExistence(timeout: 10))
            case "runwayDemo":
                XCTAssertTrue(app.buttons["runway.card"].waitForExistence(timeout: 10))
            case "employmentPayday":
                XCTAssertTrue(app.staticTexts["发薪日测试企业"].waitForExistence(timeout: 10))
            case "severance":
                XCTAssertTrue(app.staticTexts["裁员补偿"].waitForExistence(timeout: 10))
            case "socialLimits":
                XCTAssertTrue(app.buttons["profile.pension"].waitForExistence(timeout: 10))
            case "pensionShortfall":
                XCTAssertTrue(app.buttons["pension.shortfall"].waitForExistence(timeout: 10))
            case "housingShortfall":
                XCTAssertTrue(app.buttons["housing.shortfall"].waitForExistence(timeout: 10))
            case "mortgage":
                XCTAssertTrue(app.navigationBars["负债管理"].waitForExistence(timeout: 10))
            default:
                XCTFail("未定义的测试场景：\(id)")
            }
            capture(app, name: "测试场景-\(id)-\(dark ? "深色" : "浅色")")
            close.tap()
            XCTAssertTrue(app.navigationBars["测试页面"].waitForExistence(timeout: 5))
            XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: close
            )], timeout: 5) == .completed)
        }
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        app.terminate()
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
