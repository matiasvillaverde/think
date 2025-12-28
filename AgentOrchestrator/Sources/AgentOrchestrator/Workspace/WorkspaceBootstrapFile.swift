internal enum WorkspaceBootstrapFile: CaseIterable {
    case agents
    case bootstrap
    case identity
    case soul
    case tools
    case user

    internal var fileName: String {
        switch self {
        case .agents:
            return "AGENTS.md"

        case .bootstrap:
            return "BOOTSTRAP.md"

        case .identity:
            return "IDENTITY.md"

        case .soul:
            return "SOUL.md"

        case .tools:
            return "TOOLS.md"

        case .user:
            return "USER.md"
        }
    }
}
