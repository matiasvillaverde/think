import SwiftUI

// MARK: - Model Action Confirmations

/// View modifier for model action confirmation dialogs
internal struct ModelActionConfirmations: ViewModifier {
    @Binding var showDownloadConfirmation: Bool
    @Binding var showDeleteConfirmation: Bool
    let modelSize: String
    let onDownload: () -> Void
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                Text("Download Model", bundle: .module),
                isPresented: $showDownloadConfirmation
            ) {
                Button(role: .none) {
                    onDownload()
                } label: {
                    Text("Download \(modelSize) Now", bundle: .module)
                }
                Button(role: .cancel) {
                    showDownloadConfirmation = false
                } label: {
                    Text("Cancel", bundle: .module)
                }
            } message: {
                Text(
                    """
                    To use this model, \(modelSize) of data will be downloaded from the internet. \
                    Continue?
                    """,
                    bundle: .module
                )
            }
            .confirmationDialog(
                Text("Delete Model", bundle: .module),
                isPresented: $showDeleteConfirmation
            ) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text("Delete Model", bundle: .module)
                }
                Button(role: .cancel) {
                    showDeleteConfirmation = false
                } label: {
                    Text("Cancel", bundle: .module)
                }
            } message: {
                Text("Are you sure you want to delete this model?", bundle: .module)
            }
    }
}

// MARK: - View Extension

extension View {
    /// Adds model action confirmation dialogs
    func modelActionConfirmations(
        showDownloadConfirmation: Binding<Bool>,
        showDeleteConfirmation: Binding<Bool>,
        modelSize: String,
        onDownload: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(ModelActionConfirmations(
            showDownloadConfirmation: showDownloadConfirmation,
            showDeleteConfirmation: showDeleteConfirmation,
            modelSize: modelSize,
            onDownload: onDownload,
            onDelete: onDelete
        ))
    }
}
