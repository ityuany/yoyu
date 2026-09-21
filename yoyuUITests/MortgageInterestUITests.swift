import XCTest

@MainActor
final class MortgageInterestUITests: XCTestCase {
    func testMortgageInterestBreakdown() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--mortgage-ui-test"]
        app.launch()

        let mortgage = app.buttons["打开档案"].firstMatch
        XCTAssertTrue(mortgage.waitForExistence(timeout: 15), app.debugDescription)
        app.staticTexts["示例 · 自住房组合贷"].tap()
        XCTAssertFalse(app.navigationBars["示例 · 自住房组合贷"].exists)
        if !mortgage.isHittable { app.swipeUp() }
        let overview = XCTAttachment(screenshot: app.screenshot())
        overview.name = "房产证风格房贷卡片"
        overview.lifetime = .keepAlways
        add(overview)
        mortgage.tap()
        XCTAssertTrue(app.navigationBars["示例 · 自住房组合贷"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["后续预计利息"].exists)

        let rows = app.cells.containing(.staticText, identifier: "预计利息")
        XCTAssertEqual(rows.count, 3, app.debugDescription)
        var amounts: [Decimal] = []
        for index in 0..<3 {
            let row = rows.element(boundBy: index)
            if !row.isHittable { app.swipeUp() }
            let texts = row.staticTexts.allElementsBoundByIndex.map(\.label)
            let money = try XCTUnwrap(texts.first { $0.contains("¥") || $0.contains("￥") }, texts.description)
            let number = money.filter { $0.isNumber || $0 == "." || $0 == "-" }
            amounts.append(try XCTUnwrap(Decimal(string: number)))
        }
        XCTAssertGreaterThan(amounts[1], 0)
        XCTAssertGreaterThan(amounts[2], 0)
        XCTAssertEqual(amounts[0], amounts[1] + amounts[2])
        let amountsAttachment = XCTAttachment(string: "总额、公积金、商业贷款：\(amounts)")
        amountsAttachment.lifetime = .keepAlways
        add(amountsAttachment)
        app.swipeUp()
        let detail = XCTAttachment(screenshot: app.screenshot())
        detail.name = "房贷详情"
        detail.lifetime = .keepAlways
        add(detail)
        app.swipeDown()
        let top = XCTAttachment(screenshot: app.screenshot())
        top.name = "房贷详情顶部"
        top.lifetime = .keepAlways
        add(top)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(mortgage.waitForExistence(timeout: 5))
        mortgage.tap()
        XCTAssertTrue(app.navigationBars["示例 · 自住房组合贷"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.cells.containing(.staticText, identifier: "预计利息").count, 3)
        XCTAssertFalse(app.buttons["校准余额与计划"].exists)
        let edit = app.navigationBars.buttons["编辑"]
        XCTAssertTrue(edit.exists)
        edit.tap()
        XCTAssertTrue(app.navigationBars["编辑房贷"].waitForExistence(timeout: 5))
        let name = app.textFields["名称，如自住房贷款"]
        XCTAssertEqual(name.value as? String, "示例 · 自住房组合贷")
        name.tap()
        name.typeText("（取消）")
        app.buttons["取消"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "示例 · 自住房组合贷")
        name.tap()
        name.typeText("（已编辑）")
        app.buttons["保存"].tap()
        XCTAssertTrue(app.navigationBars["示例 · 自住房组合贷（已编辑）"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertFalse(app.staticTexts["校准历史"].exists)
        let edited = XCTAttachment(screenshot: app.screenshot())
        edited.name = "右上角编辑并保存名称"
        edited.lifetime = .keepAlways
        add(edited)
    }
}
