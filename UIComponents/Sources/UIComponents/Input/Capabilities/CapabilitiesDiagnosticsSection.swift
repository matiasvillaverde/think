import Abstractions
import SwiftUI

internal struct CapabilitiesDiagnosticsSection: View {
    let resolvedPolicy: ResolvedToolPolicy

    internal var body: some View {
        VStack(alignment: .leading, spacing: CapabilitiesSheet.Constants.sectionSpacing) {
            Text(String(localized: "Diagnostics", bundle: .module))
                .font(.subheadline.weight(.semibold))

            Text(String(
                localized: "Effective tools: \(resolvedPolicy.allowedTools.count)",
                bundle: .module,
                comment: "Shows number of effective tools"
            ))
            .font(.caption)
            .foregroundColor(.textSecondary)

            if !resolvedPolicy.addedTools.isEmpty {
                Text(String(
                    localized: "Added by policy: \(resolvedPolicy.addedTools.count)",
                    bundle: .module,
                    comment: "Shows tools added by allow lists"
                ))
                .font(.caption)
                .foregroundColor(.textSecondary)
            }

            if !resolvedPolicy.removedTools.isEmpty {
                Text(String(
                    localized: "Removed by policy: \(resolvedPolicy.removedTools.count)",
                    bundle: .module,
                    comment: "Shows tools removed by deny lists"
                ))
                .font(.caption)
                .foregroundColor(.textSecondary)
            }
        }
    }
}
