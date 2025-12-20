import SwiftUI
import SwiftData

#if DEBUG

public struct PreviewDatabase: PreviewModifier {
    public init() {}

    public static func makeSharedContext() throws -> ModelContainer {
        let config: ModelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container: ModelContainer = try ModelContainer(
            for:
                Model.self,
                Prompt.self,
                Message.self,
                FileAttachment.self,
            configurations: config
        )

        let context: ModelContext = container.mainContext

        PersonalityFactory.createSystemPersonalities().forEach { context.insert($0) }
        Model.previews.forEach { context.insert($0) }
        Message.allPreviews.forEach { context.insert($0) }

        return container
    }

    public func body(content: Content, context: ModelContainer) -> some View {
        // Inject the model context into the view
        content
            .modelContext(context.mainContext)
    }
}

#endif

#if DEBUG
// Similar to your PreviewModifier but specifically for the app
public struct AppPreviewDatabase: ViewModifier {
    let container: ModelContainer

    public init() {
        // Create in-memory container with preview data
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for:
                    Model.self,
                    Prompt.self,
                    Message.self,
                    Tag.self,
                configurations: config
            )

            let context = container.mainContext

            // Populate with preview data
            Model.previews.forEach { context.insert($0) }
//            Message.allPreviews.forEach { context.insert($0) }
//            Prompt.defaultPrompts().forEach { context.insert($0) }

            self.container = container
        } catch {
            fatalError("Failed to create preview container: \(error.localizedDescription)")
        }
    }

    public func body(content: Content) -> some View {
        content
            .modelContainer(container)
            .environment(\.locale, .current) // Ensure locale is properly set
    }
}
#endif
