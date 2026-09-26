import XCTest

@MainActor final class RunwayUITests: XCTestCase {
    func testCardPushAndBack() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--runway-demo"]
        app.launch()
        let card = app.buttons["runway.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 40))
        let original = app.staticTexts["runway.result"].label
        card.tap()
        XCTAssertTrue(app.staticTexts["runway.detailResult"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["runway.detailResult"].label, original)
        app.navigationBars["生存时长"].buttons.firstMatch.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["runway.result"].label, original)
    }
    func testOpeningAssetsBeforeCharts() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--runway-demo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["runway.result"].waitForExistence(timeout: 40))
        app.buttons["runway.card"].tap()
        let assetsTitle = app.staticTexts["失业起始资产"]
        let range = app.segmentedControls["runway.chartRange"]
        XCTAssertTrue(assetsTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(range.waitForExistence(timeout: 5))
        XCTAssertLessThan(assetsTitle.frame.maxY, range.frame.minY)
        XCTAssertTrue(app.staticTexts["runway.openingTotal"].exists)
        shot(app, "起点资产位于图表之前")
    }
    func testScenarioActionInTopBar() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--runway-demo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["runway.result"].waitForExistence(timeout: 40))
        XCTAssertFalse(app.buttons["runway.edit"].exists)
        app.buttons["runway.card"].tap()
        let edit = app.navigationBars["生存时长"].buttons["runway.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "runway.edit").count, 1)
        shot(app, "右上角调整情景")
        edit.tap()
        XCTAssertTrue(app.navigationBars["调整情景"].waitForExistence(timeout: 5))
    }
    func testInvestmentIncomeChartHasIndependentFullscreen() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--runway-demo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["runway.result"].waitForExistence(timeout: 40))
        app.buttons["runway.card"].tap()
        XCTAssertTrue(app.staticTexts["runway.detailResult"].waitForExistence(timeout: 5))
        shot(app, "无重复卡片的预测详情")
        let expand = app.buttons["runway.expandInvestmentIncome"]
        for _ in 0..<4 where !expand.isHittable { app.swipeUp() }
        XCTAssertTrue(expand.isHittable)
        XCTAssertTrue(app.staticTexts["理财收益如何变化"].exists)
        XCTAssertEqual(app.segmentedControls.count, 1)
        let range = app.segmentedControls["runway.chartRange"]
        XCTAssertTrue(range.waitForExistence(timeout: 5))
        for _ in 0..<3 where !range.isHittable { app.swipeDown() }
        XCTAssertTrue(range.isHittable)
        range.buttons["未来 1 年"].tap()
        for _ in 0..<3 where !expand.isHittable { app.swipeUp() }
        expand.tap()
        XCTAssertTrue(app.buttons["runway.closeInvestmentIncomeChart"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["1 年"].isSelected)
        shot(app, "横向理财收益趋势")
        app.buttons["runway.closeInvestmentIncomeChart"].tap()
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["runway.chartRange"].buttons["未来 1 年"].isSelected)
        let assetExpand = app.buttons["runway.expand"]
        for _ in 0..<4 where !assetExpand.isHittable { app.swipeDown() }
        XCTAssertTrue(assetExpand.isHittable)
        assetExpand.tap()
        XCTAssertTrue(app.buttons["runway.closeChart"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["1 年"].isSelected)
    }
    func testRequiresRetirementInformation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--runway-demo", "--runway-missing-retirement"]
        app.launch()
        let card = app.buttons["runway.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 40))
        XCTAssertTrue(app.staticTexts["请先在基本信息中完善出生年月、性别和退休类别，以计算退休时间。"].waitForExistence(timeout: 40))
        card.tap()
        XCTAssertTrue(app.buttons["runway.editRetirement"].waitForExistence(timeout: 5))
        app.buttons["runway.editRetirement"].tap()
        XCTAssertTrue(app.navigationBars["基本信息"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.navigationBars["生存时长"].buttons.firstMatch.waitForExistence(timeout: 5))
        shot(app, "展开预测详情")
        app.navigationBars["生存时长"].buttons.firstMatch.tap()
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
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND label != %@", savedResult), object: result)], timeout: 40) == .completed)
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
        XCTAssertTrue(app.navigationBars["生存时长"].buttons.firstMatch.waitForExistence(timeout: 5))
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
