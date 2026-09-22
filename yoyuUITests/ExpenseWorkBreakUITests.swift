import XCTest

@MainActor final class ExpenseWorkBreakUITests: XCTestCase {
    func testSaveCancelAndReopen() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--expense-ui-test"]
        app.launch()
        let item = app.buttons.containing(.staticText, identifier: "生活费").firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 15), app.debugDescription)
        item.tap()
        XCTAssertTrue(app.navigationBars["生活费"].waitForExistence(timeout: 5))
        app.buttons["编辑"].tap()
        let toggle = app.switches["expense.pauseDuringWorkBreak"]
        if !toggle.isHittable { app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1", app.debugDescription)
        capture(app, "工作中断暂停设置")
        app.buttons["取消"].tap()
        app.buttons["编辑"].tap()
        if !toggle.isHittable { app.swipeUp() }
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1", app.debugDescription)
        app.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts["expense.workBreakBehavior"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["expense.workBreakBehavior"].label.contains("暂停，复工后继续"))
        capture(app, "保存后的开支详情")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        item.tap()
        app.buttons["编辑"].tap()
        if !toggle.isHittable { app.swipeUp() }
        XCTAssertEqual(toggle.value as? String, "1")
        app.buttons["取消"].tap()
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
