import Abstractions
import Database
import SwiftData
import SwiftUI

private enum CanvasConstants {
    static let containerSpacing: CGFloat = 16
    static let contentPadding: CGFloat = 16
    static let editorSpacing: CGFloat = 12
    static let editorMinHeight: CGFloat = 300
    static let editorCornerRadius: CGFloat = 8
    static let editorBorderOpacity: Double = 0.2
    static let editorBorderWidth: CGFloat = 1
    static let updateDebounceNanoseconds: UInt64 = 250_000_000
}

public struct CanvasView: View {
    @Environment(\.dismiss)
    private var dismiss: DismissAction

    @Environment(\.database)
    private var database: DatabaseProtocol

    @Environment(\.modelContext)
    private var modelContext: ModelContext

    @Query private var canvases: [CanvasDocument]

    @Bindable private var chat: Chat

    @State private var activeCanvasId: UUID?
    @State private var draftTitle: String = ""
    @State private var draftContent: String = ""
    @State private var isHydrating: Bool = false
    @State private var updateScheduler: CanvasUpdateScheduler = CanvasUpdateScheduler(
        debounceNanoseconds: CanvasConstants.updateDebounceNanoseconds
    )

    public init(chat: Chat) {
        self.chat = chat
        let chatId: UUID = chat.id
        _canvases = Query(
            filter: #Predicate<CanvasDocument> { $0.chat?.id == chatId },
            sort: \CanvasDocument.updatedAt,
            order: .reverse
        )
    }

    public var body: some View {
        VStack(spacing: CanvasConstants.containerSpacing) {
            header

            if let canvas = canvases.first {
                CanvasEditor(title: $draftTitle, content: $draftContent)
                    .onAppear {
                        hydrateDraft(from: canvas)
                    }
                    .onChange(of: canvas.id) { _, _ in
                        hydrateDraft(from: canvas)
                    }
                    .onChange(of: canvas.updatedAt) { _, _ in
                        hydrateDraft(from: canvas)
                    }
                    .onChange(of: draftTitle) { _, newValue in
                        handleDraftChange(
                            canvasId: canvas.id,
                            title: newValue,
                            content: draftContent
                        )
                    }
                    .onChange(of: draftContent) { _, newValue in
                        handleDraftChange(
                            canvasId: canvas.id,
                            title: draftTitle,
                            content: newValue
                        )
                    }
            } else {
                ProgressView()
            }

            Spacer()
        }
        .padding(CanvasConstants.contentPadding)
        .task {
            await ensureCanvas()
        }
        .onDisappear {
            flushPendingUpdate()
            try? modelContext.save()
        }
    }

    private var header: some View {
        HStack {
            Text(String(
                localized: "Canvas",
                bundle: .module,
                comment: "Canvas title"
            ))
            .font(.title2)
            .fontWeight(.bold)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .accessibilityLabel("Close")
            }
            .buttonStyle(.borderless)
        }
    }

    private func ensureCanvas() async {
        _ = try? await database.write(
            CanvasCommands.GetOrCreateDefault(chatId: chat.id)
        )
    }

    private func hydrateDraft(from canvas: CanvasDocument) {
        let needsHydration: Bool = activeCanvasId != canvas.id
            || draftTitle != canvas.title
            || draftContent != canvas.content
        guard needsHydration else {
            return
        }

        isHydrating = true
        activeCanvasId = canvas.id
        draftTitle = canvas.title
        draftContent = canvas.content
        isHydrating = false
    }

    private func handleDraftChange(
        canvasId: UUID,
        title: String,
        content: String
    ) {
        guard !isHydrating else {
            return
        }
        scheduleUpdate(canvasId: canvasId, title: title, content: content)
    }

    private func scheduleUpdate(
        canvasId: UUID,
        title: String,
        content: String
    ) {
        let scheduler: CanvasUpdateScheduler = updateScheduler
        Task { [database] in
            await scheduler.scheduleUpdate(
                database: database,
                canvasId: canvasId,
                title: title,
                content: content
            )
        }
    }

    private func flushPendingUpdate() {
        guard let canvasId = activeCanvasId else {
            return
        }

        let scheduler: CanvasUpdateScheduler = updateScheduler
        let title: String = draftTitle
        let content: String = draftContent
        Task.detached(priority: .userInitiated) { [database] in
            await scheduler.flush(
                database: database,
                canvasId: canvasId,
                title: title,
                content: content
            )
        }
    }
}

private struct CanvasEditor: View {
    @Binding var title: String
    @Binding var content: String

    var body: some View {
        VStack(alignment: .leading, spacing: CanvasConstants.editorSpacing) {
            TextField("Title", text: $title)
                .font(.headline)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $content)
                .font(.body)
                .frame(minHeight: CanvasConstants.editorMinHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: CanvasConstants.editorCornerRadius)
                        .stroke(
                            Color.gray.opacity(CanvasConstants.editorBorderOpacity),
                            lineWidth: CanvasConstants.editorBorderWidth
                        )
                )
        }
    }
}

#if DEBUG
    #Preview {
        @Previewable @State var chat: Chat = .preview
        CanvasView(chat: chat)
    }
#endif
