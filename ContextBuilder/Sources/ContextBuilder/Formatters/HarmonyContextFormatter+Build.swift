import Abstractions
import Foundation

extension HarmonyContextFormatter {
    internal func build(context: BuildContext) -> String {
        var components: [String] = []
        components.reserveCapacity(Self.buildComps)
        let currentDate: Date = determineDateToUse(context: context)

        components.append(buildSystemSection(context: context, currentDate: currentDate))
        components.append(buildConversationSection(context: context))

        if !context.toolResponses.isEmpty {
            components.append("\n")
            components.append(formatToolResponses(context.toolResponses))
        }

        if shouldStartAssistantResponse(context: context) {
            components.append(formatAssistantStart(context: context))
        }

        return components.joined()
    }

    private func determineDateToUse(context: BuildContext) -> Date {
        if let override = context.contextConfiguration.currentDateOverride {
            let formatter: DateFormatter = DateFormatter()
            formatter.timeZone = TimeZone(identifier: "UTC")

            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: override) {
                return date
            }
            return ISO8601DateFormatter().date(from: override) ?? Date()
        }
        return Date()
    }

    private func buildSystemSection(context: BuildContext, currentDate: Date) -> String {
        let includeDate: Bool = context.contextConfiguration.includeCurrentDate
        let hasConversationHistory: Bool = !context.contextConfiguration.contextMessages.isEmpty
        let systemContent: String = buildSystemContent(context: context)
        let hasDeveloperSection: Bool = systemContent.contains("DEVELOPER:")
        let toolSplit: (system: [ToolDefinition], developer: [ToolDefinition]) =
            splitToolsForSections(
                tools: context.toolDefinitions,
                hasDeveloperSection: hasDeveloperSection
            )

        var components: [String] = []
        components.reserveCapacity(Self.sysComps)

        components.append(
            formatSystemMessage(
                systemContent,
                date: currentDate,
                action: context.action,
                toolDefinitions: toolSplit.system,
                allToolDefinitions: context.toolDefinitions,
                hasToolResponses: !context.toolResponses.isEmpty,
                knowledgeCutoff: context.contextConfiguration.knowledgeCutoffDate,
                includeDate: includeDate,
                hasConversationHistory: hasConversationHistory
            )
        )

        if hasDeveloperSection {
            components.append(
                buildDeveloperSection(
                    systemInstruction: context.contextConfiguration.systemInstruction,
                    toolDefinitions: toolSplit.developer
                )
            )
        }

        return components.joined()
    }

    private func buildSystemContent(context: BuildContext) -> String {
        var systemContent: String = context.contextConfiguration.systemInstruction
        if let workspaceContext: WorkspaceContext = context.contextConfiguration.workspaceContext {
            let workspaceSection: String = formatWorkspaceContext(workspaceContext)
            if !workspaceSection.isEmpty {
                systemContent += workspaceSection
            }
        }
        if let memoryContext: MemoryContext = context.contextConfiguration.memoryContext {
            let memorySection: String = formatMemoryContext(memoryContext)
            if !memorySection.isEmpty {
                systemContent += memorySection
            }
        }
        if let skillContext: SkillContext = context.contextConfiguration.skillContext {
            let skillSection: String = formatSkillContext(
                skillContext,
                actionTools: context.action.tools
            )
            if !skillSection.isEmpty {
                systemContent += skillSection
            }
        }
        return systemContent
    }

    private func buildConversationSection(context: BuildContext) -> String {
        var components: [String] = []
        let messages: [MessageData] = context.contextConfiguration.contextMessages
        components.reserveCapacity(messages.count * Self.convMult)

        for (index, message) in messages.enumerated() {
            let isLastMessage: Bool = index == messages.count - 1

            if let userInput = message.userInput {
                components.append(formatUserMessage(userInput))
            }

            if !message.channels.isEmpty {
                let isLastCompleteMessage: Bool = isLastMessage && message.userInput != nil
                let formatted: String = formatAssistantMessageFromChannels(
                    message,
                    isLast: isLastCompleteMessage
                )
                components.append(formatted)
            }
        }

        return components.joined()
    }

    private func shouldStartAssistantResponse(context: BuildContext) -> Bool {
        let contextMessages: [MessageData] = context.contextConfiguration.contextMessages
        if let lastMessage = contextMessages.last {
            return lastMessage.userInput != nil && lastMessage.channels.isEmpty
        }
        return true
    }

    private func formatAssistantStart(context: BuildContext) -> String {
        let hasNonReasoningTools: Bool = context.toolDefinitions.contains { $0.name != "reasoning" }
        if hasNonReasoningTools {
            return "<|start|>assistant\n"
        }
        return "<|start|>assistant"
    }
}
