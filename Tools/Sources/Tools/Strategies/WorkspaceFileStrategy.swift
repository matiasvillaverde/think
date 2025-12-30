import Abstractions
import Foundation
import OSLog

/// Strategy for workspace file operations (read/write/list)
public struct WorkspaceFileStrategy: ToolStrategy {
    private static let logger: Logger = Logger(
        subsystem: "Tools",
        category: "WorkspaceFileStrategy"
    )
    private let rootURL: URL

    public let definition: ToolDefinition = ToolDefinition(
        name: "workspace",
        description: "Read, write, and list files within the workspace directory",
        schema: """
        {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["read", "write", "list"],
                    "description": "Action to perform"
                },
                "path": {
                    "type": "string",
                    "description": "Relative path within the workspace"
                },
                "content": {
                    "type": "string",
                    "description": "Content to write (required for write)"
                },
                "recursive": {
                    "type": "boolean",
                    "description": "Whether to list recursively (list only)",
                    "default": false
                }
            },
            "required": ["action", "path"]
        }
        """
    )

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public func execute(request: ToolRequest) async -> ToolResponse {
        await Task.yield()
        switch BaseToolStrategy.parseArguments(request) {
        case .failure(let error):
            return BaseToolStrategy.errorResponse(request: request, error: error.message)

        case .success(let json):
            return executeRequest(request: request, json: json)
        }
    }

    private func executeRequest(request: ToolRequest, json: [String: Any]) -> ToolResponse {
        guard let action = json["action"] as? String else {
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Missing required parameter: action"
            )
        }

        guard let path = json["path"] as? String else {
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Missing required parameter: path"
            )
        }

        switch action {
        case "read":
            return readFile(request: request, path: path)

        case "write":
            let content: String? = json["content"] as? String
            return writeFile(request: request, path: path, content: content)

        case "list":
            let recursive: Bool = json["recursive"] as? Bool ?? false
            return listFiles(request: request, path: path, recursive: recursive)

        default:
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Unsupported action: \(action)"
            )
        }
    }

    private func readFile(request: ToolRequest, path: String) -> ToolResponse {
        switch resolvePath(path) {
        case .failure(let error):
            return BaseToolStrategy.errorResponse(
                request: request,
                error: error.localizedDescription
            )

        case .success(let fileURL):
            var isDirectory: ObjCBool = ObjCBool(false)
            guard FileManager.default.fileExists(
                atPath: fileURL.path,
                isDirectory: &isDirectory
            ),
                !isDirectory.boolValue
            else {
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: "File not found: \(path)"
                )
            }

            do {
                let data: Data = try Data(contentsOf: fileURL)
                guard let content = String(data: data, encoding: .utf8) else {
                    return BaseToolStrategy.errorResponse(
                        request: request,
                        error: "File is not UTF-8 text"
                    )
                }
                return BaseToolStrategy.successResponse(request: request, result: content)
            } catch {
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: error.localizedDescription
                )
            }
        }
    }

    private func writeFile(
        request: ToolRequest,
        path: String,
        content: String?
    ) -> ToolResponse {
        guard let content else {
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Missing required parameter: content"
            )
        }

        switch resolvePath(path) {
        case .failure(let error):
            return BaseToolStrategy.errorResponse(
                request: request,
                error: error.localizedDescription
            )

        case .success(let fileURL):
            do {
                let directory: URL = fileURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
                try content.data(using: .utf8)?.write(to: fileURL, options: .atomic)
                return BaseToolStrategy.successResponse(
                    request: request,
                    result: "Wrote \(content.count) characters to \(path)"
                )
            } catch {
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: error.localizedDescription
                )
            }
        }
    }

    private func listFiles(
        request: ToolRequest,
        path: String,
        recursive: Bool
    ) -> ToolResponse {
        switch resolvePath(path) {
        case .failure(let error):
            return BaseToolStrategy.errorResponse(
                request: request,
                error: error.localizedDescription
            )

        case .success(let directoryURL):
            var isDirectory: ObjCBool = ObjCBool(false)
            guard FileManager.default.fileExists(
                atPath: directoryURL.path,
                isDirectory: &isDirectory
            ),
                isDirectory.boolValue
            else {
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Directory not found: \(path)"
                )
            }

            do {
                let entries: [URL] = try listEntries(at: directoryURL, recursive: recursive)
                let payload: [String] = entries.map { relativePath(from: $0) }
                let data: Data = try JSONSerialization.data(withJSONObject: payload)
                let json: String = String(data: data, encoding: .utf8) ?? "[]"
                return BaseToolStrategy.successResponse(request: request, result: json)
            } catch {
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: error.localizedDescription
                )
            }
        }
    }

    private func resolvePath(_ path: String) -> Result<URL, ToolError> {
        let trimmed: String = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let relative: String = trimmed.isEmpty ? "." : trimmed

        if relative.hasPrefix("/") {
            return .failure(ToolError("Path must be relative to the workspace"))
        }

        let candidate: URL = rootURL.appendingPathComponent(relative).standardizedFileURL
        let root: URL = rootURL.standardizedFileURL
        let rootPath: String = root.path
        let candidatePath: String = candidate.path

        let allowed: Bool = candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
        guard allowed else {
            return .failure(ToolError("Path escapes the workspace"))
        }

        return .success(candidate)
    }

    private func listEntries(at directory: URL, recursive: Bool) throws -> [URL] {
        if recursive {
            let enumerator: FileManager.DirectoryEnumerator? = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: nil
            )
            return (enumerator?.allObjects as? [URL]) ?? []
        }
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
    }

    private func relativePath(from url: URL) -> String {
        let rootPath: String = rootURL.standardizedFileURL.path
        let path: String = url.standardizedFileURL.path
        if path == rootPath {
            return "."
        }
        if path.hasPrefix(rootPath + "/") {
            return String(path.dropFirst(rootPath.count + 1))
        }
        return url.lastPathComponent
    }
}
