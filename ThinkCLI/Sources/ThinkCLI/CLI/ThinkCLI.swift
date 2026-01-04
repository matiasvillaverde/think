import ArgumentParser

@main
struct ThinkCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "think",
        abstract: "Think CLI for chat, models, tools, RAG, and gateway operations.",
        subcommands: [
            GatewayCommand.self,
            ChatCommand.self,
            ModelsCommand.self,
            ToolsCommand.self,
            RagCommand.self,
            SkillsCommand.self,
            SchedulesCommand.self
        ]
    )
}
