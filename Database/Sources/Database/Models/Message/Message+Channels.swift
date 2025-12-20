import Foundation

// MARK: - Channel Content Helpers
extension Message {
    /// Extracts the final/user-facing content from channels
    public var response: String? {
        guard let channels = channels, !channels.isEmpty else { return nil }
        
        let responseMessages = channels
            .filter { channel in
                channel.type == .final ||
                (channel.type == .commentary && channel.recipient == "user")
            }
            .sorted { $0.order < $1.order }
            .map(\.content)
            .joined(separator: "\n")
        
        return responseMessages.isEmpty ? nil : responseMessages
    }
    
    /// Extracts the analysis/thinking content from channels
    public var thinking: String? {
        guard let channels = channels, !channels.isEmpty else { return nil }
        
        let analysisMessages = channels
            .filter { $0.type == .analysis }
            .sorted { $0.order < $1.order }
            .map(\.content)
            .joined(separator: "\n")
        
        return analysisMessages.isEmpty ? nil : analysisMessages
    }
    
    /// Gets the final channel content directly
    public var finalContent: String? {
        guard let channels = channels else { return nil }
        
        let finalMessages = channels
            .filter { $0.type == .final }
            .sorted { $0.order < $1.order }
            .map(\.content)
            .joined(separator: "\n")
        
        return finalMessages.isEmpty ? nil : finalMessages
    }
    
    /// Gets the analysis channel content directly
    public var analysisContent: String? {
        guard let channels = channels else { return nil }
        
        let analysisMessages = channels
            .filter { $0.type == .analysis }
            .sorted { $0.order < $1.order }
            .map(\.content)
            .joined(separator: "\n")
        
        return analysisMessages.isEmpty ? nil : analysisMessages
    }
    
    /// Gets commentary channel content
    public var commentaryContent: String? {
        channels?
            .filter { $0.type == .commentary && $0.recipient != "user" }
            .sorted { $0.order < $1.order }
            .map(\.content)
            .joined(separator: "\n")
    }
}