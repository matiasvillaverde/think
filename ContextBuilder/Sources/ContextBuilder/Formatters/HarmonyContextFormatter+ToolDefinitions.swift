import Abstractions
import Foundation

// MARK: - Tool Definition Methods
extension HarmonyContextFormatter {
    internal func splitToolsForSections(
        tools: [ToolDefinition],
        hasDeveloperSection: Bool
    ) -> (system: [ToolDefinition], developer: [ToolDefinition]) {
        guard hasDeveloperSection else {
            // When no developer section, all tools go in system
            return (system: tools, developer: [])
        }

        // When developer section exists, split tools:
        // - "functions" namespace tools go to developer section
        // - Other tools (like browser) stay in system section
        var systemTools: [ToolDefinition] = []
        var developerTools: [ToolDefinition] = []

        for tool in tools {
            if tool.name == "functions" {
                developerTools.append(tool)
            } else {
                systemTools.append(tool)
            }
        }

        return (system: systemTools, developer: developerTools)
    }

    internal func buildDeveloperSection(
        systemInstruction: String,
        toolDefinitions: [ToolDefinition]
    ) -> String {
        let parts: [String] = systemInstruction.components(separatedBy: "DEVELOPER:")
        guard parts.count > 1 else {
            return ""
        }

        let developerInstruction: String = parts[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return formatDeveloperMessage(developerInstruction, toolDefinitions: toolDefinitions)
    }

    internal func getToolDisplayName(_ toolName: String) -> String {
        switch toolName {
        case "browser_search", "browser.search":
            return "browser"

        case "python_execution", "python_exec":
            return "python"

        default:
            return toolName
        }
    }
    internal func formatBrowserToolDefinition() -> String {
        """
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

// Opens the link `id` from the page indicated by `cursor` starting at line number `loc`,
// showing `num_lines` lines.
// Valid link ids are displayed with the formatting: `【{id}†.*】`.
// If `cursor` is not provided, the most recent page is implied.
// If `id` is a string, it is treated as a fully qualified URL associated with `source`.
// If `loc` is not provided, the viewport will be positioned at the beginning of the document
// or centered on the most relevant passage, if available.
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
    }

    internal func formatFunctionsToolDefinition() -> String {
        """
namespace functions {

// Gets the location of the user.
type get_location = () => any;

// Gets the current weather in the provided location.
type get_current_weather = (_: {
// The city and state, e.g. San Francisco, CA
location: string,
format?: "celsius" | "fahrenheit", // default: celsius
}) => any;

// Gets the current weather in the provided list of locations.
type get_multiple_weathers = (_: {
// List of city and state, e.g. ["San Francisco, CA", "New York, NY"]
locations: string[],
format?: "celsius" | "fahrenheit", // default: celsius
}) => any;

// A function with various complex schemas.
type kitchensink = (_: // params object
{
// STRING
//
// A string
// Examples:
// - "hello"
// - "world"
string?: string,
// A nullable string
string_nullable?: string | null, // default: "the default"
string_enum?: "a" | "b" | "c",
// a oneof
// default: 20
oneof_string_or_number?:
    | string // default: "default_string_in_oneof"
    | number // numbers can happen too
,
}) => any;

} // namespace functions
"""
    }

    internal func formatPythonToolDefinition() -> String {
        """
Use this tool to execute Python code in your chain of thought. The code will not be shown to the \
user. This tool should be used for internal reasoning, but not for code that is intended to be \
visible to the user (e.g. when creating plots, tables, or files).

When you send a message containing Python code to python, it will be executed in a stateful \
Jupyter notebook environment. python will respond with the output of the execution or time out \
after 120.0 seconds. The drive at '/mnt/data' can be used to save and persist user files. \
Internet access for this session is UNKNOWN. Depends on the cluster.
"""
    }

    internal func formatReasoningToolDefinition() -> String {
        "Internal reasoning"
    }

    internal func formatDefaultToolDefinition(_ tool: ToolDefinition) -> String {
        """
\(tool.description)
"""
    }

    internal func formatToolResponses(_ responses: [ToolResponse]) -> String {
        var components: [String] = []
        // Pre-allocate for tool response sections
        components.reserveCapacity(responses.count * HarmonyContextFormatter.respMult)

        for response in responses {
            // Tool responses come from the tool to the assistant
            components.append("<|start|>functions.\(response.toolName) to=assistant")
            components.append("<|channel|>commentary<|message|>\\")
            components.append("\n\(response.result)")
            components.append("<|end|>")
        }
        return components.joined()
    }
}
