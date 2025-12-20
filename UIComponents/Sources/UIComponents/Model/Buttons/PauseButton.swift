import SwiftUI

/// A button component for pausing downloads
internal struct PauseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Pause", systemImage: "pause.fill")
                .font(.caption)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(
            Text("Pause download", bundle: .module)
        )
    }
}
