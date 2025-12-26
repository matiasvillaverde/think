import Abstractions
import RemoteSession
import SwiftUI

// MARK: - Constants

private enum SheetConstants {
    static let padding: CGFloat = 24
    static let minWidth: CGFloat = 400
    static let headerSpacing: CGFloat = 8
    static let inputSpacing: CGFloat = 8
    static let buttonSpacing: CGFloat = 12
    static let mainSpacing: CGFloat = 20
    static let progressScale: CGFloat = 0.8
}

// MARK: - API Key Entry Sheet

/// Sheet for entering an API key for a provider.
internal struct APIKeyEntrySheet: View {
    let provider: RemoteProviderType
    @Binding var apiKey: String
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let onSave: () async -> Void
    let onCancel: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: SheetConstants.mainSpacing) {
            headerSection
            keyInputSection
            errorSection
            actionButtonsSection
            helpLinkSection
        }
        .padding(SheetConstants.padding)
        .frame(minWidth: SheetConstants.minWidth)
        .onAppear {
            isTextFieldFocused = true
        }
    }

    private var headerSection: some View {
        VStack(spacing: SheetConstants.headerSpacing) {
            Text(
                String(
                    localized: "Configure \(provider.displayName)",
                    bundle: .module,
                    comment: "Title for API key entry sheet"
                )
            )
            .font(.title2)
            .fontWeight(.bold)

            Text(provider.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var keyInputSection: some View {
        VStack(alignment: .leading, spacing: SheetConstants.inputSpacing) {
            Text(
                String(
                    localized: "API Key",
                    bundle: .module,
                    comment: "Label for API key input field"
                )
            )
            .font(.subheadline)
            .fontWeight(.medium)

            SecureField(
                String(
                    localized: "Enter your API key",
                    bundle: .module,
                    comment: "Placeholder for API key input"
                ),
                text: $apiKey
            )
            .textFieldStyle(.roundedBorder)
            .focused($isTextFieldFocused)
            .disabled(isLoading)
        }
    }

    @ViewBuilder private var errorSection: some View {
        if let error = errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionButtonsSection: some View {
        HStack(spacing: SheetConstants.buttonSpacing) {
            cancelButton
            saveButton
        }
    }

    private var cancelButton: some View {
        Button {
            onCancel()
        } label: {
            Text(
                String(
                    localized: "Cancel",
                    bundle: .module,
                    comment: "Cancel button"
                )
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(isLoading)
    }

    private var saveButton: some View {
        Button {
            Task {
                await onSave()
            }
        } label: {
            saveButtonContent
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.borderedProminent)
        .disabled(apiKey.isEmpty || isLoading)
    }

    @ViewBuilder private var saveButtonContent: some View {
        if isLoading {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(SheetConstants.progressScale)
        } else {
            Text(
                String(
                    localized: "Save",
                    bundle: .module,
                    comment: "Save button"
                )
            )
        }
    }

    @ViewBuilder private var helpLinkSection: some View {
        if let signUpURL = provider.signUpURL {
            Link(destination: signUpURL) {
                HStack {
                    Text(
                        String(
                            localized: "Get an API key",
                            bundle: .module,
                            comment: "Link to get API key"
                        )
                    )
                    Image(systemName: "arrow.up.right.square")
                        .accessibilityHidden(true)
                }
                .font(.caption)
            }
        }
    }
}
