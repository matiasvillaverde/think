import Abstractions
import Database
import SwiftUI

// MARK: - Helper Views

internal struct ModelActionConfirmationDialogs: View {
    @Binding var showDownloadConfirmation: Bool
    @Binding var showDeleteConfirmation: Bool
    let formattedSize: String
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        EmptyView()
            .confirmationDialog(
                Text("Download Model", bundle: .module),
                isPresented: $showDownloadConfirmation
            ) {
                downloadConfirmationButtons
            } message: {
                downloadConfirmationMessage
            }
            .confirmationDialog(
                Text("Delete Model", bundle: .module),
                isPresented: $showDeleteConfirmation
            ) {
                deleteConfirmationButtons
            } message: {
                deleteConfirmationMessage
            }
    }

    private var downloadConfirmationButtons: some View {
        Group {
            Button(
                String(
                    localized: "Download \(formattedSize) Now",
                    bundle: .module,
                    comment: "Download button text"
                ),
                role: .none
            ) {
                onDownload()
            }
            Button(
                String(localized: "Cancel", bundle: .module, comment: "Cancel button text"),
                role: .cancel
            ) {
                showDownloadConfirmation = false
            }
        }
    }

    private var downloadConfirmationMessage: some View {
        Text(
            """
            To use this model, \(formattedSize) of data will be downloaded
            from the internet. Continue?
            """,
            bundle: .module,
            comment: "Confirmation message for downloading a model from the internet"
        )
    }

    private var deleteConfirmationButtons: some View {
        Group {
            Button(
                String(
                    localized: "Delete Model",
                    bundle: .module,
                    comment: "Delete button text"
                ),
                role: .destructive
            ) {
                onDelete()
            }
            Button(
                String(localized: "Cancel", bundle: .module, comment: "Cancel button text"),
                role: .cancel
            ) {
                showDeleteConfirmation = false
            }
        }
    }

    private var deleteConfirmationMessage: some View {
        Text(
            "Are you sure you want to delete this model?",
            bundle: .module,
            comment: "Confirmation message text to delete a model"
        )
    }
}
