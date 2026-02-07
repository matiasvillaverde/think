import ArgumentParser
import Foundation

enum CLIToolAccess: String, CaseIterable, Codable, ExpressibleByArgument, Sendable {
    case allow
    case deny
}
