import Abstractions
import Database
import OSLog
import SwiftUI

internal struct ModelCard: View {
    // MARK: - Environment Properties

    @Environment(\.colorScheme)
    private var colorScheme: ColorScheme

    @Environment(\.dismiss)
    var dismiss: DismissAction

    @Environment(\.generator)
    var generator: ViewModelGenerating

    @Environment(\.modelActionsViewModel)
    var modelActions: ModelDownloaderViewModeling

    // MARK: - State Properties

    @State private var isConfirmationPresented: Bool = false
    @State private var isDeleteConfirmationPresented: Bool = false
    @State private var isCancelConfirmationPresented: Bool = false
    @State private var isMetricsDashboardPresented: Bool = false

    // MARK: - Model Properties

    @Bindable var chat: Chat
    @Bindable var model: Model

    private var isSelected: Bool {
        model == chat.languageModel || model == chat.imageModel
    }

    // MARK: - Computed Properties for Extensions

    var isSelectedComputed: Bool { isSelected }
    var isConfirmationPresentedBinding: Binding<Bool> {
        Binding(
            get: { isConfirmationPresented },
            set: { isConfirmationPresented = $0 }
        )
    }

    var isMetricsDashboardPresentedBinding: Binding<Bool> {
        Binding(
            get: { isMetricsDashboardPresented },
            set: { isMetricsDashboardPresented = $0 }
        )
    }

    var isCancelConfirmationPresentedBinding: Binding<Bool> {
        Binding(
            get: { isCancelConfirmationPresented },
            set: { isCancelConfirmationPresented = $0 }
        )
    }

    func handleDeleteButtonTap() {
        isDeleteConfirmationPresented = true
    }

    func handleAnalyticsButtonTap() {
        isMetricsDashboardPresented = true
    }

    // MARK: - Body

    var body: some View {
        cardContent
            .accessibilityAddTraits(.isButton)
            .onTapGesture {
                handleModelSelection()
            }
            .confirmationDialog(
                Text(
                    "Download Confirmation",
                    bundle: .module,
                    comment: "Confirmation dialog title"
                ),
                isPresented: $isConfirmationPresented,
                titleVisibility: .automatic,
                actions: {
                    Button(
                        String(
                            localized: "Download \(formattedSize) Now",
                            bundle: .module,
                            comment: "Download button text"
                        ),
                        role: .none
                    ) {
                        download()
                    }
                    Button(
                        String(localized: "Cancel", bundle: .module, comment: "Cancel button text"),
                        role: .cancel
                    ) {
                        isConfirmationPresented = false
                    }
                },
                message: { confirmationMessage }
            )
            .confirmationDialog(
                Text(
                    "Delete Confirmation",
                    bundle: .module,
                    comment: "Delete confirmation dialog title"
                ),
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .automatic,
                actions: {
                    Button(
                        String(localized: "Delete", bundle: .module, comment: "Delete button text"),
                        role: .destructive
                    ) {
                        handleModelDeletion()
                    }
                    Button(
                        String(localized: "Cancel", bundle: .module, comment: "Cancel button text"),
                        role: .cancel
                    ) {
                        isDeleteConfirmationPresented = false
                    }
                },
                message: { deleteConfirmationMessage }
            )
            .confirmationDialog(
                Text(
                    "Cancel Download",
                    bundle: .module,
                    comment: "Cancel download confirmation dialog title"
                ),
                isPresented: $isCancelConfirmationPresented,
                titleVisibility: .automatic,
                actions: {
                    Button(
                        String(
                            localized: "Cancel Download",
                            bundle: .module,
                            comment: "Cancel download button text"
                        ),
                        role: .destructive
                    ) {
                        handleCancelDownload()
                    }
                    Button(
                        String(
                            localized: "Keep Downloading",
                            bundle: .module,
                            comment: "Keep downloading button text"
                        ),
                        role: .cancel
                    ) {
                        isCancelConfirmationPresented = false
                    }
                },
                message: { cancelConfirmationMessage }
            )
            .sheet(isPresented: $isMetricsDashboardPresented) {
                NavigationStack {
                    DashboardContainer(
                        context: DashboardContext(
                            modelName: model.name,
                            metrics: fetchMetricsForModel()
                        ),
                        initialType: .modelMetrics
                    )
                    .navigationTitle("Model Analytics")
                    #if !os(macOS)
                        .navigationBarTitleDisplayMode(.inline)
                    #endif
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    isMetricsDashboardPresented = false
                                }
                            }
                        }
                }
                #if os(iOS)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                #elseif os(visionOS)
                .frame(
                    minWidth: DesignConstants.Modal.minWidth,
                    minHeight: DesignConstants.Modal.minHeight
                )
                #endif
            }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(spacing: 0) {
            mainContentSection
            downloadProgressSection
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Radius.standard))
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.Radius.standard)
                .stroke(
                    Color.textSecondary.opacity(
                        DesignConstants.Opacity.backgroundSubtle
                    ),
                    lineWidth: DesignConstants.Line.thin
                )
        )
        .shadow(
            color: .black.opacity(DesignConstants.Shadow.glassMorphismOpacity),
            radius: DesignConstants.Shadow.glassMorphismRadius,
            x: DesignConstants.Shadow.xAxis,
            y: DesignConstants.Shadow.glassMorphismY
        )
    }
}

// MARK: - Previews

#if DEBUG
    #Preview {
        @Previewable @State var chat: Chat = .preview
        @Previewable @State var models: [Model] = Model.previews
        List(models) { model in
            ModelCard(
                chat: chat,
                model: model
            )
        }
    }
#endif
