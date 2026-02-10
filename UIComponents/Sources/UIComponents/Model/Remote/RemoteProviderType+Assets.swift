import Abstractions

extension RemoteProviderType {
    static func fromRemoteLocation(_ location: String) -> RemoteProviderType? {
        let prefix: Substring? = location.split(
            separator: ":",
            maxSplits: 1,
            omittingEmptySubsequences: true
        ).first
        guard let raw = prefix.map({ String($0) })?.lowercased(), !raw.isEmpty else {
            return nil
        }
        // `RemoteModel.location` uses provider.rawValue.lowercased().
        return RemoteProviderType.allCases.first { $0.rawValue.lowercased() == raw }
    }

    var assetName: String {
        switch self {
        case .openRouter:
            return "openrouter"

        case .openAI:
            return "openai"

        case .anthropic:
            return "anthropic"

        case .google:
            return "gemini"
        }
    }
}
