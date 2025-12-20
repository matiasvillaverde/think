import SwiftUI

/// A prominent button component for resuming downloads
internal struct ResumeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Resume", systemImage: "play.fill")
                .font(.caption)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel(
            Text("Resume download", bundle: .module)
        )
    }
}
