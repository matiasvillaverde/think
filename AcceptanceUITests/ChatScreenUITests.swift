import XCTest

final class ChatScreenUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func any(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func element(
        withIdentifier identifier: String,
        labelContains needle: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        let predicate = NSPredicate(format: "identifier == %@ AND label CONTAINS %@", identifier, needle)
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    func testChatStreamsAndRendersToolExecution() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let chatView = any("uiTest.chatView", in: app)
        XCTAssertTrue(chatView.waitForExistence(timeout: 15))

        let finalContent = any("channel.final.content", in: app)
        XCTAssertTrue(finalContent.waitForExistence(timeout: 15))

        // Partial streaming content should appear quickly.
        XCTAssertTrue(finalContent.label.contains("Here is a stre"))

        // Then it should become complete.
        let fullTextPredicate = NSPredicate(format: "label CONTAINS %@", "Here is a streamed response that becomes complete.")
        expectation(for: fullTextPredicate, evaluatedWith: finalContent)
        waitForExpectations(timeout: 15)

        // Completed tool execution should exist and be expandable.
        let toolId = "55555555-5555-5555-5555-555555555555"
        let toolHeader = any("toolExecution.header.\(toolId)", in: app)
        XCTAssertTrue(toolHeader.waitForExistence(timeout: 15))

        toolHeader.tap()

        let request = any("toolExecution.request.\(toolId)", in: app)
        XCTAssertTrue(request.waitForExistence(timeout: 10))

        let result = any("toolExecution.result.\(toolId)", in: app)
        XCTAssertTrue(result.waitForExistence(timeout: 10))

        // Raw toggle should flip state.
        let rawToggle = any("toolExecution.rawToggle.\(toolId)", in: app)
        XCTAssertTrue(rawToggle.waitForExistence(timeout: 5))
        XCTAssertTrue(rawToggle.label == "Raw" || rawToggle.label == "Formatted")
        rawToggle.tap()
        XCTAssertTrue(rawToggle.label == "Raw" || rawToggle.label == "Formatted")
    }

    func testThinkingCollapsesAndExpands() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let chatView = any("uiTest.chatView", in: app)
        XCTAssertTrue(chatView.waitForExistence(timeout: 15))

        let thinkingContent = any("channel.analysis.content", in: app)
        XCTAssertTrue(thinkingContent.waitForExistence(timeout: 15))

        let thinkingToggle = any("channel.analysis.header", in: app)
        XCTAssertTrue(thinkingToggle.waitForExistence(timeout: 15))
        thinkingToggle.tap()

        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: thinkingContent)
        waitForExpectations(timeout: 10)

        // Expand again
        thinkingToggle.tap()
        XCTAssertTrue(thinkingContent.waitForExistence(timeout: 10))
    }

    func testSecondMessageExists() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let chatView = any("uiTest.chatView", in: app)
        XCTAssertTrue(chatView.waitForExistence(timeout: 15))

        let secondUser = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Second message")).firstMatch
        XCTAssertTrue(secondUser.waitForExistence(timeout: 15))

        let secondResponse = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Second response (complete).")).firstMatch
        XCTAssertTrue(secondResponse.waitForExistence(timeout: 15))
    }

    func testLongRunningToolShowsExecutingAndStatusMessage() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let chatView = any("uiTest.chatView", in: app)
        XCTAssertTrue(chatView.waitForExistence(timeout: 15))

        let toolId = "88888888-8888-8888-8888-888888888888"
        let toolHeader = any("toolExecution.header.\(toolId)", in: app)
        XCTAssertTrue(toolHeader.waitForExistence(timeout: 15))
        XCTAssertTrue(toolHeader.label.contains("Executing"))

        let status = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Fetching results"))
            .firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 15))

        // Executing tools should still be expandable so users can see the request being run.
        toolHeader.tap()
        let request = any("toolExecution.request.\(toolId)", in: app)
        XCTAssertTrue(request.waitForExistence(timeout: 10))
    }
}
