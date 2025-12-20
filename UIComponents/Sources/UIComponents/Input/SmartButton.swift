import Abstractions
import Database
import SwiftUI
#if os(iOS)
    import UIKit
#endif

// MARK: - Smart Feature Button

internal struct SmartButton: View {
    @Environment(\.modelActionsViewModel)
    private var modelActions: ModelDownloaderViewModeling

    @Binding var isFeatureEnabled: Bool
    @Binding var otherFeatureToDisable: Bool

    @Bindable var model: Model

    @State private var isConfirmationPresented: Bool = false

    let title: String
    let activeIcon: String
    let inactiveIcon: String
    let helpText: String

    var body: some View {
        ToggleButton(
            title: title,
            activeIcon: activeIcon,
            inactiveIcon: inactiveIcon,
            isActive: isFeatureEnabled
        ) {
            if model.state?.isNotDownloaded == true {
                isConfirmationPresented = true
            } else {
                isFeatureEnabled.toggle()
                otherFeatureToDisable = false

                #if os(iOS)
                    // Medium impact when toggling the state
                    let impactGenerator: UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(
                        style: .medium
                    )
                    impactGenerator.prepare()
                    impactGenerator.impactOccurred()
                #endif
            }
        }
        .help(helpText)
        .confirmationDialog(
            Text(
                String(
                    localized: "Download Confirmation",
                    bundle: .module,
                    comment: "Title for the confirmation dialog when downloading a model"
                )
            ),
            isPresented: $isConfirmationPresented,
            titleVisibility: .automatic
        ) {
            confirmationButtons
        } message: {
            // swiftlint:disable line_length
            Text(
                String(
                    localized: "To enable this feature, a model needs to be downloaded from the internet. This will require \(formattedSize) of data. Please confirm to proceed.",
                    bundle: .module,
                    comment: "Message for the confirmation dialog when downloading a model."
                )
            )
            // swiftlint:enable line_length
        }
    }

    private var confirmationButtons: some View {
        Group {
            Button(
                String(
                    localized: "Download \(formattedSize) Now",
                    bundle: .module,
                    comment: "Button confirmation to download the model data"
                ),
                role: .none
            ) {
                download()
            }
            Button(
                String(
                    localized: "Cancel",
                    bundle: .module,
                    comment: "Button confirmation to cancel downloading the model data"
                ),
                role: .cancel
            ) {
                isConfirmationPresented = false
            }
        }
    }

    private var formattedSize: String {
        ByteCountFormatter.string(
            fromByteCount: Int64(model.size),
            countStyle: .file
        )
    }

    private func download() {
        Task(priority: .userInitiated) {
            // Start download with animation applied to any state changes
            await modelActions.download(modelId: model.id)
        }
    }
}

// Example of how to use SmartButton
internal struct ExampleFeatureButton: View {
    @Binding var isFeatureEnabled: Bool
    @Binding var otherFeature: Bool

    @Bindable var model: Model

    var body: some View {
        SmartButton(
            isFeatureEnabled: $isFeatureEnabled,
            otherFeatureToDisable: $otherFeature,
            model: model,
            title: String(
                localized: "Feature",
                bundle: .module,
                comment: "Button title for enabling a feature"
            ),
            activeIcon: "star.fill",
            inactiveIcon: "star",
            helpText: String(
                localized: "Enable this feature",
                bundle: .module,
                comment: "Tooltip for the feature button"
            )
        )
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var isFeatureEnabled: Bool = false
        @Previewable @State var isFeatureEnabledTrue: Bool = true
        @Previewable @State var otherFeature: Bool = false
        @Previewable @State var model: Model = Model.preview
        HStack {
            ExampleFeatureButton(
                isFeatureEnabled: $isFeatureEnabled,
                otherFeature: $otherFeature,
                model: model
            )

            ExampleFeatureButton(
                isFeatureEnabled: $isFeatureEnabledTrue,
                otherFeature: $otherFeature,
                model: model
            )
        }
    }
#endif
