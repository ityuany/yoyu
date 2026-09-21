import XCTest

@MainActor
final class SeveranceCardUITests: XCTestCase {
    func testCashDetailsNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--wealth"]
        app.launch()
        let card = app.buttons.containing(.staticText, identifier: "灵活资金").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20))
        card.tap()
        XCTAssertFalse(app.buttons["更新现金余额"].exists)
        XCTAssertFalse(app.buttons["添加现金余额"].exists)
        let details = app.buttons["查看资金详情"]
        XCTAssertTrue(details.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "灵活资金详情按钮"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        details.tap()
        XCTAssertTrue(app.navigationBars["现金"].waitForExistence(timeout: 5))
        app.buttons["编辑"].tap()
        XCTAssertTrue(app.buttons["取消"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields.firstMatch.exists)
        app.buttons["取消"].tap()
        XCTAssertTrue(app.navigationBars["现金"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(details.waitForExistence(timeout: 5))
    }

    func testWealthCardSizing() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--wealth"]
        for title in ["股票资产", "理财产品", "裁员补偿", "债务情况"] {
            app.launch()
            let card = app.buttons.containing(.staticText, identifier: title).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 20), app.debugDescription)
            card.tap()
            app.swipeUp()
            XCTAssertEqual(card.value as? String, "已展开")
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = title + "统一最低高度"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    func testCompensationPlans() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--wealth"]
        app.launch()
        let card = app.buttons.containing(.staticText, identifier: "裁员补偿").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), app.debugDescription)
        card.tap()
        app.swipeUp()
        for title in ["N", "N+1", "2N"] {
            let row = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "补偿方案 " + title + "、")).firstMatch
            XCTAssertTrue(row.isHittable, app.debugDescription)
            XCTAssertTrue(row.label.contains("¥") || row.label.contains("￥") || row.label.contains("待完善"))
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "三种裁员补偿方案"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let details = app.buttons["查看补偿方案"].firstMatch
        if details.exists {
            details.tap()
            XCTAssertTrue(app.navigationBars["补偿"].waitForExistence(timeout: 5))
            let detail = XCTAttachment(screenshot: app.screenshot())
            detail.name = "当日测算与工资基数"
            detail.lifetime = .keepAlways
            add(detail)
            app.buttons["补偿设置"].tap()
            XCTAssertTrue(app.navigationBars["补偿设置"].waitForExistence(timeout: 5))
            let cap = app.textFields["3倍社平"]
            if !cap.isHittable { app.swipeUp() }
            XCTAssertTrue(cap.isHittable, app.debugDescription)
            let settings = XCTAttachment(screenshot: app.screenshot())
            settings.name = "双封顶设置"
            settings.lifetime = .keepAlways
            add(settings)
            XCTAssertEqual(app.textFields.count, 1)
            XCTAssertEqual(app.segmentedControls.count, 0)
            XCTAssertTrue(app.buttons["保存"].isEnabled)
            app.buttons["取消"].tap()
            XCTAssertTrue(app.navigationBars["补偿"].waitForExistence(timeout: 5))
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "补偿方案 N+1、")).firstMatch.waitForExistence(timeout: 5))
        }
    }
}
