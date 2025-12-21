import Testing
@testable import RemoteSession

@Suite("SSE Parser Tests")
struct SSEParserTests {
    @Test("Parse valid SSE data line")
    func parseValidDataLine() {
        let text = "data: {\"content\": \"Hello\"}\n\n"
        let events = SSEParser.parse(text)

        #expect(events.count == 1)
        #expect(events.first?.data == "{\"content\": \"Hello\"}")
    }

    @Test("Parse SSE with multiple data lines")
    func parseMultipleDataLines() {
        let text = """
        data: line1
        data: line2

        """
        let events = SSEParser.parse(text)

        #expect(events.count == 1)
        #expect(events.first?.data == "line1\nline2")
    }

    @Test("Parse multiple events")
    func parseMultipleEvents() {
        let text = """
        data: event1

        data: event2

        """
        let events = SSEParser.parse(text)

        #expect(events.count == 2)
        #expect(events[0].data == "event1")
        #expect(events[1].data == "event2")
    }

    @Test("Handle [DONE] terminator")
    func handleDoneTerminator() {
        let text = "data: [DONE]\n\n"
        let events = SSEParser.parse(text)

        #expect(events.count == 1)
        #expect(SSEParser.isDone(events.first?.data ?? ""))
    }

    @Test("Handle empty lines (keepalive)")
    func handleEmptyLines() {
        let text = """

        data: content

        """
        let events = SSEParser.parse(text)

        #expect(events.count == 1)
        #expect(events.first?.data == "content")
    }

    @Test("Handle comments")
    func handleComments() {
        let text = """
        : this is a comment
        data: content

        """
        let events = SSEParser.parse(text)

        #expect(events.count == 1)
        #expect(events.first?.data == "content")
    }

    @Test("Parse event type")
    func parseEventType() {
        let text = """
        event: message
        data: content

        """
        let events = SSEParser.parse(text)

        #expect(events.count == 1)
        #expect(events.first?.event == "message")
        #expect(events.first?.data == "content")
    }

    @Test("Parse event ID")
    func parseEventId() {
        let text = """
        id: 123
        data: content

        """
        let events = SSEParser.parse(text)

        #expect(events.count == 1)
        #expect(events.first?.id == "123")
    }

    @Test("Handle data without trailing newline")
    func handleDataWithoutTrailingNewline() {
        let text = "data: content"
        let events = SSEParser.parse(text)

        #expect(events.count == 1)
        #expect(events.first?.data == "content")
    }

    @Test("Handle empty data")
    func handleEmptyData() {
        let text = "data: \n\n"
        let events = SSEParser.parse(text)

        #expect(events.count == 1)
        #expect(events.first?.data == "")
    }

    @Test("isDone returns true for DONE marker")
    func isDoneReturnsTrueForDoneMarker() {
        #expect(SSEParser.isDone("[DONE]"))
        #expect(SSEParser.isDone(" [DONE] "))
    }

    @Test("isDone returns false for other content")
    func isDoneReturnsFalseForOtherContent() {
        #expect(!SSEParser.isDone(""))
        #expect(!SSEParser.isDone("content"))
        #expect(!SSEParser.isDone("[done]"))
    }
}
