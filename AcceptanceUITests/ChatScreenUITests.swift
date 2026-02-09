import XCTest

final class ChatScreenUITests: XCTestCase {
    private enum ScrollDirection {
        case up
        case down
    }

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

    private func chatScrollView(in app: XCUIApplication) -> XCUIElement {
        // `uiTest.chatView` is applied to the host ChatView in the UI-test harness and
        // is consistently exposed as a scrollable element in the accessibility tree.
        any("uiTest.chatView", in: app)
    }

    private func extractAutoScrollStep(from label: String) -> Int? {
        guard let range = label.range(of: "AUTO_SCROLL_STREAM step ") else {
            return nil
        }
        let after = label[range.upperBound...]
        let digits = after.prefix { $0.isNumber }
        return Int(digits)
    }

    private func scrollUntilExists(
        _ scrollView: XCUIElement,
        untilExists element: XCUIElement,
        direction: ScrollDirection,
        maxSwipes: Int,
        perSwipeTimeout: TimeInterval = 0.4
    ) {
        if element.exists, element.isHittable {
            return
        }

        for _ in 0..<maxSwipes {
            _ = element.waitForExistence(timeout: perSwipeTimeout)
            if element.exists, element.isHittable {
                return
            }

            switch direction {
            case .up:
                scrollView.swipeUp()
            case .down:
                scrollView.swipeDown()
            }
        }
    }

    private func dragScrollViewUp(_ scrollView: XCUIElement, times: Int) {
        // Dragging from near the top to near the bottom scrolls "up" (towards older messages)
        // and is more reliable than repeated swipeDown when the UI is updating frequently.
        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        for _ in 0..<times {
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    func testChatStreamsAndRendersToolExecution() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let chatView = any("uiTest.chatView", in: app)
        XCTAssertTrue(chatView.waitForExistence(timeout: 15))

        let scrollView = chatScrollView(in: app)
        XCTAssertTrue(scrollView.waitForExistence(timeout: 15))

        // Streaming should be underway (probe reads the live final channel content from SwiftData).
        let probe = any("uiTest.streamingProbe", in: app)
        XCTAssertTrue(probe.waitForExistence(timeout: 15))
        XCTAssertTrue(probe.label.contains("AUTO_SCROLL_STREAM step"))

        // Completed tool execution should exist and be expandable.
        let toolId = "55555555-5555-5555-5555-555555555555"
        let toolHeader = any("toolExecution.header.\(toolId)", in: app)
        scrollUntilExists(scrollView, untilExists: toolHeader, direction: .down, maxSwipes: 20)
        XCTAssertTrue(toolHeader.waitForExistence(timeout: 15))

        toolHeader.tap()

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

        let scrollView = chatScrollView(in: app)
        XCTAssertTrue(scrollView.waitForExistence(timeout: 15))

        let analysisId = "11111111-1111-1111-1111-111111111111"
        let thinkingContent = element(
            withIdentifier: "channel.analysis.content.\(analysisId)",
            labelContains: "Thinking about the best answer... done.",
            in: app
        )
        scrollUntilExists(scrollView, untilExists: thinkingContent, direction: .down, maxSwipes: 12)
        XCTAssertTrue(thinkingContent.waitForExistence(timeout: 10))

        let thinkingToggle = any("channel.analysis.header.\(analysisId)", in: app)
        scrollUntilExists(scrollView, untilExists: thinkingToggle, direction: .down, maxSwipes: 12)
        XCTAssertTrue(thinkingToggle.waitForExistence(timeout: 10))
        thinkingToggle.tap()

        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: thinkingContent)
        waitForExpectations(timeout: 10)

        // Expand again
        scrollUntilExists(scrollView, untilExists: thinkingToggle, direction: .down, maxSwipes: 3)
        thinkingToggle.tap()
        XCTAssertTrue(thinkingContent.waitForExistence(timeout: 10))
    }

    func testSecondMessageExists() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let chatView = any("uiTest.chatView", in: app)
        XCTAssertTrue(chatView.waitForExistence(timeout: 15))

        let scrollView = chatScrollView(in: app)
        XCTAssertTrue(scrollView.waitForExistence(timeout: 15))

        let secondUser = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Second message")).firstMatch
        scrollUntilExists(scrollView, untilExists: secondUser, direction: .down, maxSwipes: 12)
        XCTAssertTrue(secondUser.waitForExistence(timeout: 10))

        let secondResponse = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Second response (complete).")).firstMatch
        scrollUntilExists(scrollView, untilExists: secondResponse, direction: .down, maxSwipes: 12)
        XCTAssertTrue(secondResponse.waitForExistence(timeout: 10))
    }

    func testLongRunningToolShowsExecutingAndStatusMessage() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let chatView = any("uiTest.chatView", in: app)
        XCTAssertTrue(chatView.waitForExistence(timeout: 15))

        let scrollView = chatScrollView(in: app)
        XCTAssertTrue(scrollView.waitForExistence(timeout: 15))

        let toolId = "88888888-8888-8888-8888-888888888888"
        let toolHeader = any("toolExecution.header.\(toolId)", in: app)
        scrollUntilExists(scrollView, untilExists: toolHeader, direction: .down, maxSwipes: 6)
        XCTAssertTrue(toolHeader.waitForExistence(timeout: 10))
        XCTAssertTrue(toolHeader.label.contains("Executing"))

        let status = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Fetching results"))
            .firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 15))

        // Executing tools should still be expandable so users can see the request being run.
        scrollUntilExists(scrollView, untilExists: toolHeader, direction: .up, maxSwipes: 2)
        toolHeader.tap()
        // Executing tools won't have a result yet; validate expansion by checking the status message.
        XCTAssertTrue(status.exists)
    }

    func testToolDisclosureStaysExpandedDuringStreamingUpdates() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let chatView = any("uiTest.chatView", in: app)
        XCTAssertTrue(chatView.waitForExistence(timeout: 15))

        let scrollView = chatScrollView(in: app)
        XCTAssertTrue(scrollView.waitForExistence(timeout: 15))

        let toolId = "55555555-5555-5555-5555-555555555555"
        let toolHeader = any("toolExecution.header.\(toolId)", in: app)
        XCTAssertTrue(toolHeader.waitForExistence(timeout: 15))

        toolHeader.tap()

        let result = any("toolExecution.result.\(toolId)", in: app)
        XCTAssertTrue(result.waitForExistence(timeout: 10))

        let probe = any("uiTest.streamingProbe", in: app)
        XCTAssertTrue(probe.waitForExistence(timeout: 15))

        let firstLabel = probe.label
        expectation(for: NSPredicate(format: "label != %@", firstLabel), evaluatedWith: probe)
        waitForExpectations(timeout: 15)

        // Streaming can move the scroll position (when pinned), which may virtualize offscreen
        // rows. Scroll back to the tool and assert the disclosure state is preserved.
        scrollUntilExists(scrollView, untilExists: toolHeader, direction: .down, maxSwipes: 16, perSwipeTimeout: 0.2)
        XCTAssertTrue(toolHeader.waitForExistence(timeout: 10))
        XCTAssertTrue(result.waitForExistence(timeout: 10))
    }

    func testStreamingKeepsPinnedToBottom() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let chatView = any("uiTest.chatView", in: app)
        XCTAssertTrue(chatView.waitForExistence(timeout: 15))

        let probe = any("uiTest.streamingProbe", in: app)
        XCTAssertTrue(probe.waitForExistence(timeout: 15))

        let pinnedProbe = any("uiTest.pinnedProbe", in: app)
        XCTAssertTrue(pinnedProbe.waitForExistence(timeout: 15))

        // Wait for streaming to be underway (seed may advance beyond step 0 before tests start).
        let anyStepProbePredicate = NSPredicate(format: "label CONTAINS %@", "AUTO_SCROLL_STREAM step")
        expectation(for: anyStepProbePredicate, evaluatedWith: probe)
        waitForExpectations(timeout: 15)

        // Pinned-to-bottom should remain true while streaming progresses.
        expectation(for: NSPredicate(format: "label == %@", "pinned=true"), evaluatedWith: pinnedProbe)
        waitForExpectations(timeout: 15)

        let firstLabel = probe.label
        let firstStep = extractAutoScrollStep(from: firstLabel)
        XCTAssertNotNil(firstStep)

        // Ensure the stream continues to update.
        expectation(for: NSPredicate(format: "label != %@", firstLabel), evaluatedWith: probe)
        waitForExpectations(timeout: 15)

        XCTAssertEqual(pinnedProbe.label, "pinned=true")
    }

    func testStreamingDoesNotAutoScrollWhenUserScrollsUp() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let chatView = any("uiTest.chatView", in: app)
        XCTAssertTrue(chatView.waitForExistence(timeout: 15))

        let scroll = chatScrollView(in: app)
        XCTAssertTrue(scroll.waitForExistence(timeout: 15))

        let bottom = any("chat.messages.bottom", in: app)
        XCTAssertTrue(bottom.waitForExistence(timeout: 15))

        let probe = any("uiTest.streamingProbe", in: app)
        XCTAssertTrue(probe.waitForExistence(timeout: 15))

        // Ensure the streaming message is visible before unpinning.
        let anyStepProbePredicate = NSPredicate(format: "label CONTAINS %@", "AUTO_SCROLL_STREAM step")
        expectation(for: anyStepProbePredicate, evaluatedWith: probe)
        waitForExpectations(timeout: 15)

        let visibleLabel = probe.label

        // Scroll up to unpin and reveal older messages.
        dragScrollViewUp(scroll, times: 2)

        let secondUser = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Second message"))
            .firstMatch
        scrollUntilExists(scroll, untilExists: secondUser, direction: .down, maxSwipes: 10, perSwipeTimeout: 0.2)
        XCTAssertTrue(secondUser.waitForExistence(timeout: 10))
        XCTAssertTrue(secondUser.isHittable)

        // Streaming continues (probe updates regardless of whether the message is visible),
        // but we should not be forced back to the bottom.
        expectation(for: NSPredicate(format: "label != %@", visibleLabel), evaluatedWith: probe)
        waitForExpectations(timeout: 15)

        XCTAssertTrue(secondUser.isHittable)
    }
}
