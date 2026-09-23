import XCTest

@MainActor final class RunwayUITests: XCTestCase {
    func testEdgeReturnAndPress() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--runway-demo"]
        app.launch()
        let card = app.buttons["runway.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 40))
        XCTAssertTrue(app.staticTexts["runway.result"].waitForExistence(timeout: 40))
        XCTAssertFalse(card.images["arrow.up.left.and.arrow.down.right"].exists)
        let original = app.staticTexts["runway.result"].label
        shot(app, "无图标整卡入口")
        // Hold long enough for the recording to show the finger-down pose.
        card.press(forDuration: 0.65)
        waitForOpen(app)
        shot(app, "按压回弹展开")
        let left = app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.45))
        let short = app.coordinate(withNormalizedOffset: CGVector(dx: 0.13, dy: 0.45))
        left.press(forDuration: 0.05, thenDragTo: short, withVelocity: .slow, thenHoldForDuration: 0.3)
        waitForOpen(app)
        XCTAssertEqual(app.staticTexts["runway.detailResult"].label, original)
        shot(app, "短滑取消后恢复全屏")
        // A horizontal gesture away from the edge must not dismiss the detail.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.25))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.25)))
        waitForOpen(app)
        app.swipeUp()
        shot(app, "滚动后边缘返回前")
        left.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.83, dy: 0.45)), withVelocity: .slow, thenHoldForDuration: 0.15)
        waitForClosed(app)
        XCTAssertEqual(app.staticTexts["runway.result"].label, original)
        shot(app, "边缘返回原卡片")
        openCard(app)
        app.buttons["runway.closeDetail"].tap()
        waitForClosed(app)
    }
    func testCardExpansionMotion() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--runway-demo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["runway.result"].waitForExistence(timeout: 40))
        let card = app.buttons["runway.card"]
        let originalFrame = card.frame
        let originalResult = app.staticTexts["runway.result"].label
        shot(app, "卡片展开前")
        openCard(app)
        let close = app.buttons["runway.closeDetail"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: close)], timeout: 5) == .completed)
        shot(app, "卡片展开后")
        close.tap()
        waitForClosed(app)
        XCTAssertEqual(card.frame.minY, originalFrame.minY, accuracy: 1)
        XCTAssertEqual(card.frame.height, originalFrame.height, accuracy: 1)
        XCTAssertEqual(app.staticTexts["runway.result"].label, originalResult)
        openCard(app)
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        app.swipeUp()
        shot(app, "滚动后关闭前")
        close.tap()
        waitForClosed(app)
        XCTAssertEqual(card.frame.minY, originalFrame.minY, accuracy: 1)
        XCTAssertEqual(app.staticTexts["runway.result"].label, originalResult)
        shot(app, "收回原卡片")
    }
    func testScenarioAndChart() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--runway-demo"]
        let started = ContinuousClock.now
        app.launch()
        var result = app.staticTexts["runway.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 40), app.debugDescription)
        XCTAssertTrue(app.staticTexts["runway.example"].exists)
        print("RUNWAY_UI launch_to_result=\(started.duration(to: .now))")
        let original = result.label
        shot(app, "生存时长首屏")
        XCTAssertFalse(app.buttons["runway.edit"].exists)
        openCard(app)
        XCTAssertTrue(app.buttons["runway.closeDetail"].waitForExistence(timeout: 5))
        shot(app, "展开预测详情")
        app.buttons["runway.closeDetail"].tap()
        waitForClosed(app)
        openCard(app)
        result = app.staticTexts["runway.detailResult"]
        app.buttons["runway.edit"].tap()
        let field = app.textFields["灵活收入"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        // Replace the draft without depending on the keyboard's Select All menu.
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + "0")
        app.buttons["取消"].tap()
        XCTAssertEqual(result.label, original)
        app.buttons["runway.edit"].tap()
        XCTAssertEqual(field.value as? String, "2000")
        shot(app, "情景配置")
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "0")
        XCTAssertEqual(field.value as? String, "0")
        app.buttons["runway.save"].tap()
        XCTAssertTrue(result.waitForExistence(timeout: 40))
        XCTAssertTrue(waitForLabel(result, differentFrom: original))
        let savedResult = result.label
        app.buttons["runway.edit"].tap()
        app.buttons["runway.mode"].tap()
        app.buttons["阶段失业"].tap()
        app.buttons["runway.save"].tap()
        XCTAssertTrue(result.waitForExistence(timeout: 40))
        app.buttons["runway.edit"].tap()
        app.buttons["runway.mode"].tap()
        app.buttons["持续在职"].tap()
        app.buttons["runway.save"].tap()
        XCTAssertTrue(result.waitForExistence(timeout: 40))
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "可持续生存"), object: result)], timeout: 40) == .completed)
        app.buttons["runway.edit"].tap()
        app.buttons["runway.mode"].tap()
        app.buttons["不再就业"].tap()
        app.buttons["runway.save"].tap()
        XCTAssertTrue(result.waitForExistence(timeout: 40))
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", savedResult), object: result)], timeout: 10) == .completed)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        let expand = app.buttons["runway.expand"]
        if !expand.isHittable { app.swipeUp() }
        XCTAssertTrue(expand.isHittable)
        shot(app, "资产趋势与构成")
        app.segmentedControls.buttons["未来 1 年"].tap()
        expand.tap()
        XCTAssertTrue(app.buttons["runway.closeChart"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["1 年"].isSelected)
        shot(app, "横向全屏趋势")
        app.buttons["runway.closeChart"].tap()
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["未来 1 年"].isSelected)
        for _ in 0..<3 where !app.buttons["runway.breakdown"].isHittable { app.swipeUp() }
        app.buttons["runway.breakdown"].tap()
        XCTAssertTrue(app.navigationBars["收支明细"].waitForExistence(timeout: 5))
        shot(app, "逐月收支")
    }
    func testRequiredDates() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--runway-demo", "--runway-unconfigured"]
        app.launch()
        XCTAssertTrue(app.staticTexts["runway.result"].waitForExistence(timeout: 40))
        openCard(app)
        let close = app.buttons["runway.closeDetail"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in close.isEnabled }, object: close)], timeout: 5) == .completed, "关闭按钮应在展开完成后启用")
        app.buttons["runway.edit"].tap()
        XCTAssertTrue(app.buttons["runway.mode"].waitForExistence(timeout: 5))
        app.buttons["runway.mode"].tap()
        app.buttons["阶段失业"].tap()
        let save = app.buttons["runway.save"]
        XCTAssertFalse(save.isEnabled)
        app.buttons["runway.setLoss"].tap()
        XCTAssertFalse(save.isEnabled)
        app.buttons["runway.setReturn"].tap()
        XCTAssertFalse(save.isEnabled)
        app.textFields["就业薪资"].tap()
        app.textFields["就业薪资"].typeText("9000")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts["runway.detailResult"].waitForExistence(timeout: 40))
    }
    private func openCard(_ app: XCUIApplication) {
        app.buttons["runway.card"].tap()
        waitForOpen(app)
    }
    private func waitForOpen(_ app: XCUIApplication) {
        let close = app.buttons["runway.closeDetail"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in close.isEnabled }, object: close)], timeout: 5) == .completed, "关闭按钮应在展开完成后启用")
    }
    private func waitForClosed(_ app: XCUIApplication) {
        let card = app.buttons["runway.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in card.isHittable }, object: card)], timeout: 5) == .completed, "卡片应在收起完成后重新可点按")
    }
    private func waitForLabel(_ element: XCUIElement, differentFrom value: String) -> Bool {
        XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND label != %@", value), object: element)], timeout: 40) == .completed
    }
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
