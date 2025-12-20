import Foundation

// MARK: - File Support

/// Represents the file types supported by the RAG system for content extraction and processing
public enum SupportedFileType {
    /// Comma-separated values file format
    case csv
    /// Microsoft Word document format
    case docx
    /// JavaScript Object Notation file format
    case json
    /// Markdown text file format
    case markdown
    /// Portable Document Format
    case pdf
    /// Plain text file format
    case text

    static func detect(from url: URL) -> Self? {
        switch url.pathExtension.lowercased() {
        case "pdf":
            return .pdf

        case "txt":
            return .text

        case "md", "markdown":
            return .markdown

        case "json":
            return .json

        case "csv":
            return .csv

        case "docx":
            return .docx

        default:
            return nil
        }
    }

    var debugDescription: String {
        switch self {
        case .csv:
            return "csv"

        case .docx:
            return "docx"

        case .json:
            return "json"

        case .markdown:
            return "markdown"

        case .pdf:
            return "pdf"

        case .text:
            return "text"
        }
    }
}
