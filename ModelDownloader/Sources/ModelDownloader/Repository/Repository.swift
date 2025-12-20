import Foundation

/// Type of repository on HuggingFace Hub
internal enum RepositoryType: String, Sendable {
    case model = "models"
    case dataset = "datasets"
    case space = "spaces"
}

/// Represents a repository on HuggingFace Hub
internal struct Repository: Sendable {
    /// Repository namespace (organization or user)
    internal let namespace: String

    /// Repository name
    internal let name: String

    /// Repository type
    internal let type: RepositoryType

    /// HuggingFace Hub endpoint
    internal let endpoint: String

    /// Full repository ID (namespace/name or just name)
    internal var id: String {
        namespace.isEmpty ? name : "\(namespace)/\(name)"
    }

    /// Initialize repository from ID string
    /// - Parameters:
    ///   - id: Repository ID (e.g., "facebook/opt-125m" or just "gpt2")
    ///   - type: Repository type (defaults to .model)
    ///   - endpoint: Hub endpoint (defaults to https://huggingface.co)
    internal init(id: String, type: RepositoryType = .model, endpoint: String = "https://huggingface.co") {
        self.endpoint = endpoint

        // Handle special prefixes for datasets and spaces
        var cleanId: String = id
        var inferredType: RepositoryType = type

        if id.hasPrefix("datasets/") {
            cleanId = String(id.dropFirst("datasets/".count))
            inferredType = .dataset
        } else if id.hasPrefix("spaces/") {
            cleanId = String(id.dropFirst("spaces/".count))
            inferredType = .space
        }

        self.type = inferredType

        // Parse namespace and name
        let components: [Substring] = cleanId.split(separator: "/", maxSplits: 1)
        if components.count == 2 {
            self.namespace = String(components[0])
            self.name = String(components[1])
        } else {
            self.namespace = ""
            self.name = cleanId
        }
    }

    /// Get the API URL for listing files
    /// - Parameters:
    ///   - revision: Git revision (branch, tag, or commit)
    ///   - recursive: Whether to recursively list files in subdirectories
    /// - Returns: URL for the files API endpoint
    internal func filesAPIURL(revision: String, recursive: Bool = true) -> URL {
        let path: String = "\(endpoint)/api/\(type.rawValue)/\(id)/tree/\(revision)"
        if recursive {
            return URL(string: "\(path)?recursive=true")!
        }
        return URL(string: path)!
    }

    /// Get the download URL for a specific file
    /// - Parameters:
    ///   - path: File path within the repository
    ///   - revision: Git revision (branch, tag, or commit)
    /// - Returns: URL for downloading the file
    internal func downloadURL(path: String, revision: String) -> URL {
        let urlPath: String = "\(endpoint)/\(id)/resolve/\(revision)/\(path)"
        return URL(string: urlPath)!
    }
}
