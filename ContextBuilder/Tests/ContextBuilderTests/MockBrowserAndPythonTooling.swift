import Abstractions
import Foundation

/// Mock tooling that provides browser and python tools for testing
internal actor MockBrowserAndPythonTooling: Tooling {
    // swiftlint:disable line_length
    private let browserDescription = """
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

    // Opens the link `id` from the page indicated by `cursor` starting at line number `loc`, showing `num_lines` lines.
    // Valid link ids are displayed with the formatting: `【{id}†.*】`.
    // If `cursor` is not provided, the most recent page is implied.
    // If `id` is a string, it is treated as a fully qualified URL associated with `source`.
    // If `loc` is not provided, the viewport will be positioned at the beginning of the document or centered on the most relevant passage, if available.
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

    private let pythonDescription = """
    Use this tool to execute Python code in your chain of thought. The code will not be shown to the user. This tool should be used for internal reasoning, but not for code that is intended to be visible to the user (e.g. when creating plots, tables, or files).

    When you send a message containing Python code to python, it will be executed in a stateful Jupyter notebook environment. python will respond with the output of the execution or time out after 120.0 seconds. The drive at '/mnt/data' can be used to save and persist user files. Internet access for this session is UNKNOWN. Depends on the cluster.
    """
    // swiftlint:enable line_length

    func configureTool(identifiers _: Set<ToolIdentifier>) async throws {
        await Task.yield()
    }

    func clearTools() async {
        await Task.yield()
    }

    func getToolDefinitions(for identifiers: Set<ToolIdentifier>) async -> [ToolDefinition] {
        await Task.yield()
        var tools: [ToolDefinition] = []

        if identifiers.contains(.browser) {
            tools.append(ToolDefinition(
                name: "browser.search",
                description: browserDescription,
                schema: "{}"
            ))
        }

        if identifiers.contains(.python) {
            tools.append(ToolDefinition(
                name: "python_exec",
                description: pythonDescription,
                schema: "{}"
            ))
        }

        return tools
    }

    func getAllToolDefinitions() async -> [ToolDefinition] {
        await Task.yield()
        return await getToolDefinitions(for: [.browser, .python])
    }

    func executeTools(toolRequests _: [ToolRequest]) async throws -> [ToolResponse] {
        await Task.yield()
        return []
    }

    func configureSemanticSearch(
        database _: DatabaseProtocol,
        chatId _: UUID,
        fileTitles _: [String]
    ) async throws {
        await Task.yield()
    }
}
