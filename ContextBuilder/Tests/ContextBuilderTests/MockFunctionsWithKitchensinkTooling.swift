import Abstractions
import Foundation

/// Mock tooling that provides functions namespace with kitchensink for testing
internal actor MockFunctionsWithKitchensinkTooling: Tooling {
    private let functionsDescription = """
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

    func configureTool(identifiers _: Set<ToolIdentifier>) async {
        await Task.yield()
    }

    func clearTools() async {
        await Task.yield()
    }

    func getToolDefinitions(for identifiers: Set<ToolIdentifier>) async -> [ToolDefinition] {
        await Task.yield()
        guard identifiers.contains(.functions) else {
            return []
        }

        return [
            ToolDefinition(
                name: "functions",
                description: functionsDescription,
                schema: "{}"
            )
        ]
    }

    func getAllToolDefinitions() async -> [ToolDefinition] {
        await Task.yield()
        return await getToolDefinitions(for: [.functions])
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
