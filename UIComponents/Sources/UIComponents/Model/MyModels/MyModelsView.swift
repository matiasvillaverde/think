import Abstractions
import Database
import OSLog
import SwiftData
import SwiftUI

/// A view that displays the user's downloaded and downloading models
internal struct MyModelsView: View {
    // MARK: - Properties

    let chat: Chat
    @Binding var isDiscoveryPresented: Bool

    // MARK: - Initialization

    init(chat: Chat, isDiscoveryPresented: Binding<Bool>) {
        self.chat = chat
        _isDiscoveryPresented = isDiscoveryPresented
    }

    init(chat: Chat) {
        self.chat = chat
        _isDiscoveryPresented = .constant(false)
    }

    @Query private var models: [Model]

    #if os(macOS)
        @Environment(\.openWindow)
        private var openWindow: OpenWindowAction
        @Environment(\.dismiss)
        private var dismiss: DismissAction
    #endif

    // MARK: - Computed Properties

    private var downloadingModels: [Model] {
        models.filter { $0.state?.isDownloading == true }
    }

    private var downloadedModels: [Model] {
        models.filter { $0.state?.isDownloaded == true && $0.state?.isDownloading != true }
    }

    private var hasModels: Bool {
        !downloadingModels.isEmpty || !downloadedModels.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if hasModels {
                    modelsContent
                } else {
                    MyModelsEmptyState()
                }
            }
        }
        .background(Color.backgroundPrimary)
    }

    // MARK: - Private Views

    private var modelsContent: some View {
        ScrollView {
            VStack(spacing: DesignConstants.Spacing.large) {
                if !downloadingModels.isEmpty {
                    downloadingSection
                }

                if !downloadedModels.isEmpty {
                    downloadedSection
                }
            }
            .padding(.horizontal, DesignConstants.Spacing.large)
            .padding(.vertical, DesignConstants.Spacing.large)
        }
    }

    private var downloadingSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                    .accessibilityLabel("Downloading")

                Text("Downloading", bundle: .module)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)

                Spacer()
            }
            .padding(.horizontal, DesignConstants.Spacing.small)

            ModelGroupView(
                models: downloadingModels,
                title: "",
                chat: chat
            )
        }
    }

    private var downloadedSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
            HStack {
                Text("My Models", bundle: .module)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text("\(downloadedModels.count)", bundle: .module)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, DesignConstants.Spacing.small)
                    .padding(.vertical, DesignConstants.Spacing.xSmall)
                    .background(
                        Capsule()
                            .fill(Color.backgroundSecondary)
                    )
            }
            .padding(.horizontal, DesignConstants.Spacing.small)

            ModelGroupView(
                models: downloadedModels,
                title: "",
                chat: chat
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var isDiscoveryPresented: Bool = false
        MyModelsView(chat: .preview, isDiscoveryPresented: $isDiscoveryPresented)
    }
#endif
