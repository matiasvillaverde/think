import ArgumentParser
import Foundation

enum CLIOutputFormat: String, CaseIterable, Codable, ExpressibleByArgument, Sendable {
    case text = "text"
    case json = "json"
    case jsonLines = "json-lines"
}
