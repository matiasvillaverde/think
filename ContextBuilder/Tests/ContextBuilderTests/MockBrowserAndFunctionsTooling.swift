import Abstractions
import Foundation

internal actor MockBrowserAndFunctionsTooling: Tooling {
    private let browserDefinitionText = """
    // Tool for browsing.
    // The `cursor` appears in brackets before each browsing display: `[{cursor}]`.
    // Cite information from the tool using the following format:
    // `【{cursor}†L{line_start}(-L{line_end})?】`, for example: `【6†L9-L11】` or `【8†L3】`.
    // Do not quote more than 10 words directly from the tool output.
    // sources=web (default: web)
    namespace browser {

    // Searches for information related to `query` and displays `topn` results.
    type search = (_: {
    query: string,
    topn?: number, // default: 10
    source?: string,
    }) => any;

    // Opens the link `id` from the page indicated by `cursor` starting at line number `loc`, \
    showing `num_lines` lines.
    // Valid link ids are displayed with the formatting: `【{id}†.*】`.
    // If `cursor` is not provided, the most recent page is implied.
    // If `id` is a string, it is treated as a fully qualified URL associated with `source`.
    // If `loc` is not provided, the viewport will be positioned at the beginning of the \
    document or centered on the most relevant passage, if available.
    // Use this function without `id` to scroll to a new location of an opened page.
    type open = (_: {
    id?: number | string, // default: -1
    cursor?: number, // default: -1
    loc?: number, // default: -1
    num_lines?: number, // default: -1
    view_source?: boolean, // default: false
    source?: string,
    }) => any;

    // Finds exact matches of `pattern` in the current page, or the page given by `cursor`.
    type find = (_: {
    pattern: string,
    cursor?: number, // default: -1
    }) => any;

    } // namespace browser
    """

    private let functionsDefinitionText = """
    namespace functions {

    // Use this tool to lookup the weather in a given location. Call it with the parameter \
    'location', can be any textual description of a location.
    type lookup_weather = (_: {
    location: string,
    }) => any;

    } // namespace functions
    """

    func configureTool(identifiers _: Set<ToolIdentifier>) async {
        await Task.yield()
    }

    func clearTools() async {
        await Task.yield()
    }

    func getToolDefinitions(for identifiers: Set<ToolIdentifier>) async -> [ToolDefinition] {
        await Task.yield()
        var tools: [ToolDefinition] = []

        if identifiers.contains(.browser) {
            tools.append(getBrowserTool())
        }

        if identifiers.contains(.functions) {
            tools.append(getFunctionsTool())
        }

        return tools
    }

    private func getBrowserTool() -> ToolDefinition {
        ToolDefinition(
            name: "browser.search",
            description: browserDefinitionText.trimmingCharacters(in: .whitespacesAndNewlines),
            schema: """
            {
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "enum": ["search", "open", "find"]
                    },
                    "query": {"type": "string"},
                    "id": {"type": "string"},
                    "pattern": {"type": "string"}
                }
            }
            """
        )
    }

    private func getFunctionsTool() -> ToolDefinition {
        ToolDefinition(
            name: "functions",
            description: functionsDefinitionText.trimmingCharacters(in: .whitespacesAndNewlines),
            schema: "{}"
        )
    }

    func getAllToolDefinitions() async -> [ToolDefinition] {
        await Task.yield()
        return await getToolDefinitions(for: [.browser, .functions])
    }

    func executeTools(toolRequests _: [ToolRequest]) async -> [ToolResponse] {
        await Task.yield()
        return []
    }

    func configureSemanticSearch(
        database _: DatabaseProtocol,
        chatId _: UUID,
        fileTitles _: [String]
    ) async {
        await Task.yield()
    }
}
