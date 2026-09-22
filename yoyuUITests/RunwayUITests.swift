import XCTest

@MainActor final class RunwayUITests: XCTestCase {
    func testScenarioAndChart() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--runway-demo"]
        let started = ContinuousClock.now
        app.launch()
        let result = app.staticTexts["runway.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 40), app.debugDescription)
        XCTAssertTrue(app.staticTexts["runway.example"].exists)
        print("RUNWAY_UI launch_to_result=\(started.duration(to: .now))")
        let original = result.label
        shot(app, "生存时长首屏")
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
        app.segmentedControls["runway.mode"].buttons["阶段失业"].tap()
        XCTAssertTrue(result.waitForExistence(timeout: 40))
        app.segmentedControls["runway.mode"].buttons["持续在职"].tap()
        XCTAssertTrue(result.waitForExistence(timeout: 40))
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "可持续生存"), object: result)], timeout: 40) == .completed)
        app.segmentedControls["runway.mode"].buttons["不再就业"].tap()
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
        app.segmentedControls["runway.mode"].buttons["阶段失业"].tap()
        XCTAssertTrue(app.staticTexts["runway.missing"].waitForExistence(timeout: 10))
        app.buttons["runway.edit"].tap()
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
        XCTAssertTrue(app.staticTexts["runway.result"].waitForExistence(timeout: 40))
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
