// swiftlint:disable line_length
import Abstractions
import Database
import Foundation
#if os(iOS)
import UIKit
#endif

/// ViewModelGenerator implementation using AgentOrchestrator
public final actor ViewModelGenerator: ViewModelGenerating {
    private let orchestrator: AgentOrchestrating
    private let database: DatabaseProtocol

    public init(
        orchestrator: AgentOrchestrating,
        database: DatabaseProtocol
    ) {
        self.orchestrator = orchestrator
        self.database = database
    }

    public func load(chatId: UUID) async {
        do {
            try await orchestrator.load(chatId: chatId)
        } catch {
            await notify(message: error.localizedDescription, type: .error)
        }
    }

    public func unload() async {
        do {
            try await orchestrator.unload()
            await notify(message: String(localized: "Unloaded models successfully", bundle: .module), type: .success)
        } catch {
            await notify(message: error.localizedDescription, type: .error)
        }
    }

    public func generate(prompt: String, overrideAction: Abstractions.Action?) async {
        // Trigger a strong haptic feedback when prompt is received
        #if os(iOS)
        let notificationFeedback: UINotificationFeedbackGenerator = await UINotificationFeedbackGenerator()
        await notificationFeedback.prepare()
        await notificationFeedback.notificationOccurred(.success)
        #endif

        let action: Action = overrideAction ?? .textGeneration([])

        Task(priority: .userInitiated) {
            do {
                try await orchestrator.generate(prompt: prompt, action: action)
            } catch {
                await notify(message: error.localizedDescription, type: .error)
            }
        }
    }

    public func stop() async {
        do {
            try await orchestrator.stop()
        } catch {
            await notify(message: error.localizedDescription, type: .error)
        }
    }

    public func modify(chatId: UUID, modelId: UUID) async {
        do {
            // Update the model in database
            try await database.write(ChatCommands.UpdateChatModel(chatId: chatId, modelId: modelId))

            // Reload the chat to use the new model
            try await orchestrator.load(chatId: chatId)

            // Get model name for notification
            let name: String = try await database.read(ModelCommands.GetModelName(id: modelId))
            await notify(
                message: String(
                    localized: "\(name) is now ready to use in this chat.",
                    bundle: .module
                ),
                type: .success
            )
        } catch {
            await notify(message: error.localizedDescription, type: .error)
        }
    }

    public func modelWasUnloaded(id: UUID) {
        // AgentOrchestrator handles model state internally
        // This is kept for protocol conformance but may not be needed
    }

    private func notify(message: String, type: NotificationType) async {
        #if os(iOS)
        // Provide error feedback if generation fails
        let notificationFeedback: UINotificationFeedbackGenerator = await UINotificationFeedbackGenerator()
        await notificationFeedback.prepare()
        switch type {
        case .success:
            await notificationFeedback.notificationOccurred(.success)

        case .error:
            await notificationFeedback.notificationOccurred(.error)

        case .warning:
            await notificationFeedback.notificationOccurred(.warning)

        default:
            await notificationFeedback.notificationOccurred(.success)
        }
        #endif
        _ = try? await database.write(
            NotificationCommands.Create(
                type: type,
                message: message
            )
        )
    }
}
// swiftlint:enable line_length
