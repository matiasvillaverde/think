import Database

// MARK: - Dashboard Context

/// Context information for dashboard display
public struct DashboardContext {
    /// The single metric to display
    public let metric: Metrics?
    /// The chat ID for filtering metrics
    public let chatId: String?
    /// The chat title for display
    public let chatTitle: String?
    /// The model name for filtering
    public let modelName: String?
    /// Collection of metrics to display
    public let metrics: [Metrics]

    /// Initializes a new dashboard context
    public init(
        metric: Metrics? = nil,
        chatId: String? = nil,
        chatTitle: String? = nil,
        modelName: String? = nil,
        metrics: [Metrics] = []
    ) {
        self.metric = metric
        self.chatId = chatId
        self.chatTitle = chatTitle
        self.modelName = modelName
        self.metrics = metrics
    }
}
