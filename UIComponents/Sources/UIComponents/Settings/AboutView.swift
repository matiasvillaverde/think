import SwiftUI

// swiftlint:disable closure_body_length

public struct AboutView: View {
    private enum Constants {
        static let contentPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 20
        static let itemSpacing: CGFloat = 8
        static let iconSize: CGFloat = 60
        static let cornerRadius: CGFloat = 12
        static let infoRowMinWidth: CGFloat = 100
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "Unknown"
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Constants.sectionSpacing) {
                appHeader
                Divider()
                appInfoSection
                Spacer()
            }
            .padding(Constants.contentPadding)
        }
    }

    private var appHeader: some View {
        VStack(spacing: Constants.itemSpacing) {
            Image(systemName: "cpu")
                .font(.system(size: Constants.iconSize))
                .foregroundColor(.marketingSecondary)
                .accessibility(label: Text("App icon", bundle: .module))

            Text(String(
                localized: "Think AI",
                bundle: .module,
                comment: "App name in about section"
            ))
            .font(.title2)
            .fontWeight(.bold)

            Text(String(
                localized: "Local AI for Everyone",
                bundle: .module,
                comment: "App tagline in about section"
            ))
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }

    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: Constants.itemSpacing) {
            infoRow(
                label: String(
                    localized: "Version",
                    bundle: .module,
                    comment: "App version label"
                ),
                value: "\(appVersion) (\(buildNumber))"
            )

            infoRow(
                label: String(
                    localized: "Bundle ID",
                    bundle: .module,
                    comment: "Bundle identifier label"
                ),
                value: bundleIdentifier
            )

            infoRow(
                label: String(
                    localized: "Platform",
                    bundle: .module,
                    comment: "Platform label"
                ),
                value: platformString
            )

            infoRow(
                label: String(
                    localized: "Developer",
                    bundle: .module,
                    comment: "Developer label"
                ),
                value: "Matias Villaverde"
            )

            infoRow(
                label: String(
                    localized: "Website",
                    bundle: .module,
                    comment: "Website label"
                ),
                value: "think.app"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(minWidth: Constants.infoRowMinWidth, alignment: .leading)

            Text(value)
                .textSelection(.enabled)
                .foregroundColor(.primary)

            Spacer()
        }
    }

    private var platformString: String {
        #if os(iOS)
            return "iOS"
        #elseif os(macOS)
            return "macOS"
        #elseif os(visionOS)
            return "visionOS"
        #else
            return "Unknown"
        #endif
    }
}

#if DEBUG
    #Preview {
        AboutView()
            .frame(width: 400, height: 500)
    }
#endif

// swiftlint:enable closure_body_length
