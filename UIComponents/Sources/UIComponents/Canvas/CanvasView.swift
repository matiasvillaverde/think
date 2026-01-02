import Database
import SwiftData
import SwiftUI

public struct CanvasView: View {
    @Environment(\.dismiss)
    private var dismiss: DismissAction

    @Environment(\.database)
    private var database: DatabaseProtocol

    @Environment(\.modelContext)
    private var modelContext: ModelContext

    @Query private var canvases: [CanvasDocument]

    @Bindable private var chat: Chat

    public init(chat: Chat) {
        self.chat = chat
        let chatId = chat.id
        _canvases = Query(
            filter: #Predicate<CanvasDocument> { $0.chat?.id == chatId },
            sort: \CanvasDocument.updatedAt,
            order: .reverse
        )
    }

    public var body: some View {
        VStack(spacing: 16) {
            header

            if let canvas = canvases.first {
                CanvasEditor(canvas: canvas)
            } else {
                ProgressView()
            }

            Spacer()
        }
        .padding(16)
        .task {
            await ensureCanvas()
        }
        .onDisappear {
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
}

private struct CanvasEditor: View {
    @Bindable var canvas: CanvasDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $canvas.title)
                .font(.headline)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $canvas.content)
                .font(.body)
                .frame(minHeight: 300)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
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
