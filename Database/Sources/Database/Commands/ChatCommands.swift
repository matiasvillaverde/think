import Foundation
import SwiftData
import OSLog
import Abstractions
import SwiftUI

// swiftlint:disable line_length nesting

// MARK: - Chat Commands
public enum ChatCommands {
    // All commands are now in extension files:
    // - ChatCommands+Create.swift: Create, CreateWithModel, ResetAllChats
    // - ChatCommands+Read.swift: Read, GetAll, GetFirst, HasChats
    // - ChatCommands+Model.swift: GetLanguageModel, GetImageModel, HaveSameModels, ModifyChatModelsCommand, GetLLMConfiguration, GetLanguageModelConfiguration, GetVisualLanguageModelConfiguration
    // - ChatCommands+Management.swift: Rename, Delete, AutoRenameFromContent
    // - ChatCommands+Attachments.swift: HasAttachments, AttachmentFileTitles
    // - ChatCommands+Context.swift: FetchContextData, FetchTableName, and data types (ContextConfiguration, MessageData, ChatData)
}
