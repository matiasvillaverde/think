import Foundation

/// A parsed Server-Sent Event.
struct SSEEvent: Equatable, Sendable {
    /// The event type (optional, defaults to "message")
    let event: String?

    /// The event data
    let data: String

    /// The event ID (optional)
    let id: String?

    /// Creates a new SSE event.
    init(event: String? = nil, data: String, id: String? = nil) {
        self.event = event
        self.data = data
        self.id = id
    }
}

/// Parser for Server-Sent Events (SSE) format.
///
/// SSE is a simple text-based protocol where events are separated by blank lines.
/// Each event can have multiple fields:
/// - `event:` - The event type
/// - `data:` - The event data (can span multiple lines)
/// - `id:` - The event ID
/// - `:` - Comments (ignored)
///
/// Example SSE stream:
/// ```
/// data: {"content": "Hello"}
///
/// data: {"content": " world"}
///
/// data: [DONE]
/// ```
enum SSEParser {
    /// The terminator string that signals end of stream.
    static let doneMarker = "[DONE]"

    /// Parses SSE data from a chunk of bytes.
    ///
    /// This method handles partial data by buffering incomplete lines.
    /// It returns all complete events found in the data.
    ///
    /// - Parameter data: The raw bytes received from the stream
    /// - Returns: An array of parsed SSE events
    static func parse(_ data: Data) -> [SSEEvent] {
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }
        return parse(text)
    }

    /// Parses SSE data from a string.
    ///
    /// - Parameter text: The SSE formatted text
    /// - Returns: An array of parsed SSE events
    static func parse(_ text: String) -> [SSEEvent] {
        var events: [SSEEvent] = []
        var currentEvent: String?
        var currentData: [String] = []
        var currentId: String?

        // Split by lines, handling both \n and \r\n
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            if line.isEmpty {
                // Empty line signals end of event
                if !currentData.isEmpty {
                    let data = currentData.joined(separator: "\n")
                    events.append(SSEEvent(
                        event: currentEvent,
                        data: data,
                        id: currentId
                    ))
                }
                // Reset for next event
                currentEvent = nil
                currentData = []
                currentId = nil
                continue
            }

            // Parse field
            if line.hasPrefix(":") {
                // Comment, ignore
                continue
            }

            let colonIndex = line.firstIndex(of: ":")
            let field: String
            let value: String

            if let index = colonIndex {
                field = String(line[..<index])
                var valueStart = line.index(after: index)
                // Skip optional space after colon
                if valueStart < line.endIndex && line[valueStart] == " " {
                    valueStart = line.index(after: valueStart)
                }
                value = String(line[valueStart...])
            } else {
                field = line
                value = ""
            }

            switch field {
            case "event":
                currentEvent = value
            case "data":
                currentData.append(value)
            case "id":
                currentId = value
            default:
                // Unknown field, ignore
                break
            }
        }

        // Handle any remaining event without trailing newline
        if !currentData.isEmpty {
            let data = currentData.joined(separator: "\n")
            events.append(SSEEvent(
                event: currentEvent,
                data: data,
                id: currentId
            ))
        }

        return events
    }

    /// Checks if the event data indicates end of stream.
    ///
    /// - Parameter data: The event data to check
    /// - Returns: True if this is the [DONE] terminator
    static func isDone(_ data: String) -> Bool {
        data.trimmingCharacters(in: .whitespaces) == doneMarker
    }
}
