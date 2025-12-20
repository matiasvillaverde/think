import Foundation
import SwiftData
import Testing
@testable import Database

@Suite("Channel Model Tests")
struct ChannelTests {
    // MARK: - Basic Properties Tests
    
    @Test("Channel initializes with required properties")
    func channelInitializesWithRequiredProperties() {
        // Given
        let id = UUID()
        let type = Channel.ChannelType.final
        let content = "Test content"
        let order = 0
        
        // When
        let channel = Channel(
            id: id,
            type: type,
            content: content,
            order: order
        )
        
        // Then
        #expect(channel.id == id)
        #expect(channel.type == type)
        #expect(channel.content == content)
        #expect(channel.order == order)
        #expect(channel.recipient == nil)
        #expect(channel.associatedToolId == nil)
        #expect(channel.isComplete == false)
        #expect(channel.lastUpdated != nil)
    }
    
    @Test("Channel initializes with all properties")
    func channelInitializesWithAllProperties() {
        // Given
        let id = UUID()
        let type = Channel.ChannelType.commentary
        let content = "Commentary content"
        let order = 1
        let recipient = "functions.web_search"
        let associatedToolId = UUID()
        
        // When
        let channel = Channel(
            id: id,
            type: type,
            content: content,
            order: order,
            recipient: recipient,
            associatedToolId: associatedToolId,
            isComplete: true
        )
        
        // Then
        #expect(channel.id == id)
        #expect(channel.type == type)
        #expect(channel.content == content)
        #expect(channel.order == order)
        #expect(channel.recipient == recipient)
        #expect(channel.associatedToolId == associatedToolId)
        #expect(channel.isComplete == true)
    }
    
    // MARK: - SwiftData Model Tests
    
    @Test("Channel conforms to PersistentModel")
    @MainActor
    func channelConformsToPersistentModel() throws {
        // Given
        let container = try ModelContainer(
            for: Channel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        
        // When
        let channel = Channel(
            id: UUID(),
            type: .final,
            content: "Test",
            order: 0
        )
        context.insert(channel)
        try context.save()
        
        // Then
        let descriptor = FetchDescriptor<Channel>()
        let channels = try context.fetch(descriptor)
        #expect(channels.count == 1)
        #expect(channels.first?.content == "Test")
    }
    
    // MARK: - Conversion Tests
    
    @Test("Channel initializes from migration constructor")
    func channelInitializesFromMigrationConstructor() {
        // Given
        let toolId = UUID()
        
        // When
        let channel = Channel(
            type: .analysis,
            content: "Analysis content",
            order: 2,
            recipient: "user",
            associatedToolId: toolId
        )
        
        // Then
        #expect(channel.type == .analysis)
        #expect(channel.content == "Analysis content")
        #expect(channel.order == 2)
        #expect(channel.recipient == "user")
        #expect(channel.associatedToolId == toolId)
        #expect(channel.isComplete == false)
    }
    
    @Test("Channel properties are accessible")
    func channelPropertiesAreAccessible() {
        // Given
        let toolId = UUID()
        let channel = Channel(
            id: UUID(),
            type: .final,
            content: "Final content",
            order: 3,
            recipient: "python",
            associatedToolId: toolId,
            isComplete: true
        )
        
        // Then - Verify all properties are accessible
        #expect(channel.type == .final)
        #expect(channel.content == "Final content")
        #expect(channel.order == 3)
        #expect(channel.recipient == "python")
        #expect(channel.associatedToolId == toolId)
        #expect(channel.isComplete == true)
    }
    
    // MARK: - Tool Channel Type Tests
    
    @Test("Channel initializes with tool type")
    func channelInitializesWithToolType() {
        // Given
        // When
        let channel = Channel(
            type: .tool,
            content: "{\"name\": \"calculator\", \"arguments\": {\"a\": 1, \"b\": 2}}",
            order: 1
        )
        
        // Then
        #expect(channel.type == .tool)
        #expect(channel.content.contains("calculator") == true)
    }
    
    @Test("ChannelType includes all expected cases")
    func channelTypeIncludesAllCases() {
        // Given/When
        let allCases = Channel.ChannelType.allCases
        
        // Then
        #expect(allCases.count == 4)
        #expect(allCases.contains(.analysis))
        #expect(allCases.contains(.commentary))
        #expect(allCases.contains(.final))
        #expect(allCases.contains(.tool))
    }
    
    @Test("Tool channel persists with correct type")
    @MainActor
    func toolChannelPersistsWithCorrectType() throws {
        // Given
        let container = try ModelContainer(
            for: Channel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        
        // When
        let channel = Channel(
            type: .tool,
            content: "{\"name\": \"web_search\", \"arguments\": {\"query\": \"test\"}}",
            order: 2,
        )
        context.insert(channel)
        try context.save()
        
        // Then - fetch all and filter in memory to avoid predicate issues
        let descriptor = FetchDescriptor<Channel>()
        let allChannels = try context.fetch(descriptor)
        let toolChannels = allChannels.filter { $0.type == .tool }
        
        #expect(toolChannels.count == 1)
        #expect(toolChannels.first?.type == .tool)
        #expect(toolChannels.first?.content.contains("web_search") == true)
    }
    
    // MARK: - Tool Channel Tests
    
    @Test("Channel initializes with tool content")
    func channelInitializesWithToolContent() {
        // Given tool content JSON
        
        // When
        let channel = Channel(
            id: UUID(),
            type: .tool,
            content: "{\"name\": \"web_search\", \"arguments\": {\"query\": \"test\"}}",
            order: 1
        )
        
        // Then
        #expect(channel.type == .tool)
        #expect(channel.content.contains("web_search") == true)
    }
    
    @Test("Channel initializes without tool content")
    func channelInitializesWithoutToolContent() {
        // Given/When
        let channel = Channel(
            id: UUID(),
            type: .final,
            content: "Response content",
            order: 0
        )
        
        // Then
        #expect(channel.type != .tool)
    }
    
    @Test("Channel with tool type persists in SwiftData")
    @MainActor
    func channelWithToolTypePersists() throws {
        // Given
        let container = try ModelContainer(
            for: Channel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        
        // When
        let channel = Channel(
            id: UUID(),
            type: .tool,
            content: "{\"name\": \"calculator\", \"arguments\": {\"operation\": \"add\", \"a\": 1, \"b\": 2}}",
            order: 1
        )
        context.insert(channel)
        try context.save()
        
        // Then
        let descriptor = FetchDescriptor<Channel>()
        let channels = try context.fetch(descriptor)
        #expect(channels.count == 1)
        #expect(channels.first?.type == .tool)
        #expect(channels.first?.content.contains("calculator") == true)
    }
    
    // MARK: - Update Tests
    
    @Test("Channel updates content correctly")
    func channelUpdatesContent() {
        // Given
        let channel = Channel(
            id: UUID(),
            type: .final,
            content: "Initial content",
            order: 0
        )
        let originalDate = channel.lastUpdated
        
        // When
        channel.updateContent("Updated content")
        
        // Then
        #expect(channel.content == "Updated content")
        #expect(channel.lastUpdated > originalDate)
    }
    
    @Test("Channel marks as complete")
    func channelMarksAsComplete() {
        // Given
        let channel = Channel(
            id: UUID(),
            type: .analysis,
            content: "Analysis",
            order: 0
        )
        #expect(channel.isComplete == false)
        
        // When
        channel.markAsComplete()
        
        // Then
        #expect(channel.isComplete == true)
    }
}