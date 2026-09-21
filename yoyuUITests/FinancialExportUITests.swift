import XCTest

@MainActor final class FinancialExportUITests: XCTestCase {
    func testPreviewCopyAndDismiss() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--financial-export-ui-test"]
        app.launch()
        let entry = app.buttons["profile.financialExport"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        capture(app, "我的-导出入口")
        entry.tap()
        let content = app.staticTexts["financialExport.content"]
        XCTAssertTrue(content.waitForExistence(timeout: 10))
        XCTAssertTrue(content.label.contains("现金：¥100,000.00"), content.label)
        XCTAssertTrue(content.label.contains("## 未来 12 个完整月份的已知支出"))
        let copy = app.buttons["financialExport.copy"]
        copy.tap()
        XCTAssertTrue(app.staticTexts["financialExport.copyStatus"].label.contains("已复制"))
        capture(app, "财务摘要-已复制")
        app.buttons["完成"].tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        XCTAssertTrue(content.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["financialExport.copy"].label.contains("复制 Markdown"))
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
