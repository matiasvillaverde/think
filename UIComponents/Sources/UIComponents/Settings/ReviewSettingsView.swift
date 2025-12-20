import SwiftUI

// **MARK: - General Settings View**
public struct ReviewSettingsView: View {
    // **MARK: - Body**
    public var body: some View {
        List {
            // Empty list as requested, to be built later
            Text(String(
                localized: "No settings available",
                bundle: .module,
                comment: "Placeholder for empty general settings"
            ))
            .foregroundColor(.secondary)
        }
    }
}
