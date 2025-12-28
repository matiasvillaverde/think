import Abstractions
import Foundation

extension SubAgentCoordinator {
    internal func requestMessage(
        request: SubAgentRequest,
        contextConfig: ContextConfiguration
    ) -> MessageData {
        let channels: [MessageChannel] = contextConfig.contextMessages.first?.channels ?? []
        let toolRequests: [ToolCall] = contextConfig.contextMessages.first?.toolCalls ?? []
        return createMessageData(request: request, channels: channels, toolRequests: toolRequests)
    }

    internal func applyRequestContext(
        request: SubAgentRequest,
        contextConfig: ContextConfiguration
    ) -> ContextConfiguration {
        let message: MessageData = requestMessage(request: request, contextConfig: contextConfig)
        return contextConfig.withMessages([message])
    }

    internal func applyToolContext(
        request: SubAgentRequest,
        contextConfig: ContextConfiguration,
        generated: GeneratedOutput,
        toolRequests: [ToolRequest]
    ) -> ContextConfiguration {
        let messageChannels: [MessageChannel] = convertChannels(generated.processed.channels)
        let message: MessageData = createMessageData(
            request: request,
            channels: messageChannels,
            toolRequests: makeToolCalls(from: toolRequests)
        )
        return contextConfig.withMessages([message])
    }

    internal func makeToolCalls(from requests: [ToolRequest]) -> [ToolCall] {
        requests.map { request in
            ToolCall(name: request.name, arguments: request.arguments, id: request.id.uuidString)
        }
    }

    private func convertChannels(_ channels: [ChannelMessage]) -> [MessageChannel] {
        channels.compactMap { channel in
            switch channel.type {
            case .commentary:
                return MessageChannel(
                    type: .commentary,
                    content: channel.content,
                    order: channel.order,
                    associatedToolId: channel.toolRequest?.id
                )

            case .final:
                return MessageChannel(
                    type: .final,
                    content: channel.content,
                    order: channel.order,
                    associatedToolId: channel.toolRequest?.id
                )

            case .analysis, .tool:
                return nil
            }
        }
    }

    internal struct ToolLoopInputs {
        internal let request: SubAgentRequest
        internal let runContext: SubAgentRunContext
        internal let tooling: SubAgentTooling
        internal let startTime: Date
    }

    internal struct ToolLoopState {
        internal let toolResponses: [ToolResponse]
        internal let toolsUsed: [String]
        internal let contextConfig: ContextConfiguration
    }

    internal struct IterationOutput {
        internal let generated: GeneratedOutput
        internal let toolRequests: [ToolRequest]
        internal let contextConfig: ContextConfiguration
    }

    internal enum ToolLoopOutcome {
        case completed(SubAgentResult)
        case failed(SubAgentResult)
        case `continue`(ToolLoopState)
    }
}
