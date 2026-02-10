import SwiftUI

/// A destructive button component for canceling downloads
internal struct CancelDownloadButton: View {
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Label {
                Text("Cancel", bundle: .module)
            } icon: {
                Image(systemName: "xmark")
            }
            .font(.caption)
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(
            Text("Cancel download", bundle: .module)
        )
    }
}
