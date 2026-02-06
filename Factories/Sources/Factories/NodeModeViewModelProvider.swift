import Abstractions
import AgentOrchestrator
import Database
import LLamaCPP
import MLXSession
import ModelDownloader
import RemoteSession
import SwiftUI
import ViewModels

// MARK: - Node Mode Provider

public struct NodeModeViewModelProvider: ViewModifier {
    @Environment(\.database)
    private var database: DatabaseProtocol

    public init() {
        // Initialize provider
    }

    public func body(content: Content) -> some View {
        let orchestrator: AgentOrchestrating = AgentOrchestratorFactory.make(
            database: database,
            mlxSession: MLXSessionFactory.create(),
            ggufSession: LlamaCPPFactory.createSession(),
            options: .init(
                remoteSession: RemoteSessionFactory.create(),
                modelDownloader: ModelDownloader.shared
            )
        )
        let gateway: GatewayServicing = LocalGatewayService(
            database: database,
            orchestrator: orchestrator
        )
        let nodeModeViewModel: NodeModeViewModeling = NodeModeViewModel(
            database: database,
            gateway: gateway
        )

        return content
            .environment(\.nodeModeViewModel, nodeModeViewModel)
    }
}

extension View {
    public func withNodeModeViewModel() -> some View {
        modifier(NodeModeViewModelProvider())
    }
}

// MARK: - Automation Scheduler Provider

public struct AutomationSchedulerProvider: ViewModifier {
    @Environment(\.database)
    private var database: DatabaseProtocol

    @State private var scheduler: AutomationScheduler?

    public init() {
        // Initialize provider
    }

    public func body(content: Content) -> some View {
        content.task {
            if scheduler == nil {
                let orchestrator: AgentOrchestrating = AgentOrchestratorFactory.make(
                    database: database,
                    mlxSession: MLXSessionFactory.create(),
                    ggufSession: LlamaCPPFactory.createSession(),
                    options: .init(
                        remoteSession: RemoteSessionFactory.create(),
                        modelDownloader: ModelDownloader.shared
                    )
                )
                let newScheduler: AutomationScheduler = AutomationScheduler(
                    database: database,
                    orchestrator: orchestrator
                )
                scheduler = newScheduler
                await newScheduler.start()
            }
        }
    }
}

extension View {
    public func withAutomationScheduler() -> some View {
        modifier(AutomationSchedulerProvider())
    }
}
