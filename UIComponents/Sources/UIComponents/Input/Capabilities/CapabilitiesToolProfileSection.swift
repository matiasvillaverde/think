import Abstractions
import SwiftUI

internal struct CapabilitiesToolProfileSection: View {
    @Binding var draftProfile: ToolProfile
    let onProfileChanged: () -> Void

    internal var body: some View {
        VStack(alignment: .leading, spacing: CapabilitiesSheet.Constants.sectionSpacing) {
            Text(String(localized: "Tool Profile", bundle: .module))
                .font(.subheadline.weight(.semibold))

            Picker(
                String(localized: "Tool Profile", bundle: .module),
                selection: $draftProfile
            ) {
                ForEach(ToolProfile.allCases, id: \.self) { profile in
                    Text(profile.displayName).tag(profile)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: draftProfile) { _, _ in
                onProfileChanged()
            }

            Text(draftProfile.profileDescription)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }
}
