import Abstractions
import SwiftUI

/// A reusable metadata item for displaying structured information
internal struct MetadataItem: Identifiable, Sendable {
    let id: UUID = .init()
    let label: String
    let value: String
    let systemImageName: String?
    let url: URL?

    init(
        label: String,
        value: String,
        systemImageName: String? = nil,
        url: URL? = nil
    ) {
        self.label = label
        self.value = value
        self.systemImageName = systemImageName
        self.url = url
    }
}

/// A generic, reusable component for displaying structured metadata
///
/// Follows existing design patterns with consistent styling, accessibility,
/// and localization support. Supports both static items and interactive links.
internal struct MetadataSection: View {
    // MARK: - Properties

    private let title: String
    private let items: [MetadataItem]
    private let showDividers: Bool

    // MARK: - State

    @State private var showingSafariView: Bool = false
    @State private var safariURL: URL?

    // MARK: - Initialization

    /// Creates a metadata section
    /// - Parameters:
    ///   - title: Section title
    ///   - items: Array of metadata items to display
    ///   - showDividers: Whether to show dividers between items
    init(
        title: String,
        items: [MetadataItem],
        showDividers: Bool = true
    ) {
        self.title = title
        self.items = items.filter { !$0.value.isEmpty } // Filter out empty values
        self.showDividers = showDividers
    }

    // MARK: - Body

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
                sectionHeader
                sectionContent
            }
            .sheet(isPresented: $showingSafariView) {
                if let url = safariURL {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
        }
    }

    // MARK: - Private Views

    private var sectionHeader: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private var sectionContent: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                metadataRow(item)

                if showDividers, index < items.count - 1 {
                    Divider()
                        .opacity(DesignConstants.Opacity.line)
                }
            }
        }
        .padding(.horizontal, DesignConstants.Spacing.large)
        .padding(.vertical, DesignConstants.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignConstants.Radius.standard)
                .fill(Color.backgroundSecondary)
        )
    }

    @ViewBuilder
    private func metadataRow(_ item: MetadataItem) -> some View {
        if let url = item.url {
            interactiveRow(item, url: url)
        } else {
            staticRow(item)
        }
    }

    private func staticRow(_ item: MetadataItem) -> some View {
        HStack(alignment: .top, spacing: DesignConstants.Spacing.medium) {
            if let iconName = item.systemImageName {
                Image(systemName: iconName)
                    .font(.body)
                    .foregroundColor(.marketingSecondary)
                    .frame(width: MetadataConstants.iconWidth, alignment: .leading)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
                Text(item.label)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)

                Text(item.value)
                    .font(.body)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.label): \(item.value)")
    }

    private func interactiveRow(_ item: MetadataItem, url: URL) -> some View {
        Button {
            safariURL = url
            showingSafariView = true
        } label: {
            HStack(alignment: .top, spacing: DesignConstants.Spacing.medium) {
                if let iconName = item.systemImageName {
                    Image(systemName: iconName)
                        .font(.body)
                        .foregroundColor(.marketingSecondary)
                        .frame(width: MetadataConstants.iconWidth, alignment: .leading)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
                    Text(item.label)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)

                    Text(item.value)
                        .font(.body)
                        .foregroundColor(.accentColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.label): \(item.value)")
        .accessibilityHint(String(localized: "Tap to open link", bundle: .module))
        .accessibilityAddTraits(.isLink)
    }

    // MARK: - Factory Methods

    /// Creates a metadata section from ModelCardData
    /// - Parameters:
    ///   - title: Section title
    ///   - cardData: ModelCardData to extract metadata from
    /// - Returns: MetadataSection with relevant items
    static func fromCardData(title: String, cardData: ModelCardData) -> Self {
        var items: [MetadataItem] = []

        // Base model information
        if !cardData.baseModel.isEmpty {
            let baseModelText: String = cardData.baseModel.joined(separator: ", ")
            items.append(MetadataItem(
                label: String(localized: "Base Model", bundle: .module),
                value: baseModelText,
                systemImageName: "building.columns"
            ))
        }

        // Pipeline information
        if let pipeline = cardData.pipelineTag {
            items.append(MetadataItem(
                label: String(localized: "Pipeline", bundle: .module),
                value: pipeline.capitalized,
                systemImageName: "flowchart"
            ))
        }

        // Library information
        if let library = cardData.libraryName {
            items.append(MetadataItem(
                label: String(localized: "Framework", bundle: .module),
                value: library,
                systemImageName: "gear"
            ))
        }

        // Language support
        if !cardData.language.isEmpty {
            let languageText: String = cardData.language.joined(separator: ", ")
            items.append(MetadataItem(
                label: String(localized: "Languages", bundle: .module),
                value: languageText,
                systemImageName: "globe"
            ))
        }

        // Training datasets
        if !cardData.datasets.isEmpty {
            let datasetText: String = cardData.datasets.joined(separator: ", ")
            items.append(MetadataItem(
                label: String(localized: "Datasets", bundle: .module),
                value: datasetText,
                systemImageName: "doc.text"
            ))
        }

        // License information with link
        if let license = cardData.license {
            let licenseURL: URL? = cardData.licenseLink.flatMap(URL.init(string:))
            items.append(MetadataItem(
                label: String(localized: "License", bundle: .module),
                value: license,
                systemImageName: "document.fill",
                url: licenseURL
            ))
        }

        return Self(title: title, items: items)
    }

    /// Creates a technical specifications section
    /// - Parameter cardData: ModelCardData to extract specs from
    /// - Returns: MetadataSection with technical details
    static func technicalSpecs(from cardData: ModelCardData) -> Self {
        var items: [MetadataItem] = []

        if let pipeline = cardData.pipelineTag {
            items.append(MetadataItem(
                label: String(localized: "Model Type", bundle: .module),
                value: pipeline.replacingOccurrences(of: "-", with: " ").capitalized,
                systemImageName: "cpu"
            ))
        }

        if let library = cardData.libraryName {
            items.append(MetadataItem(
                label: String(localized: "ML Framework", bundle: .module),
                value: library,
                systemImageName: "gearshape.2"
            ))
        }

        if let relation = cardData.baseModelRelation {
            items.append(MetadataItem(
                label: String(localized: "Model Relation", bundle: .module),
                value: relation.capitalized,
                systemImageName: "link"
            ))
        }

        return Self(
            title: String(localized: "Technical Specifications", bundle: .module),
            items: items
        )
    }
}

// MARK: - Constants

private enum MetadataConstants {
    static let iconWidth: CGFloat = 20
}

// MARK: - Preview

#if DEBUG
    #Preview("Metadata Section") {
        PreviewContent()
    }

    private struct PreviewContent: View {
        var body: some View {
            ScrollView {
                VStack(spacing: DesignConstants.Spacing.huge) {
                    sampleSection
                    emptySection
                    cardDataSection
                }
                .padding()
            }
            .background(Color.backgroundPrimary)
        }

        private var sampleSection: some View {
            MetadataSection(
                title: "Model Information",
                items: [
                    MetadataItem(
                        label: "Base Model",
                        value: "microsoft/DialoGPT-medium",
                        systemImageName: "building.columns"
                    ),
                    MetadataItem(
                        label: "Pipeline",
                        value: "text-generation",
                        systemImageName: "flowchart"
                    ),
                    MetadataItem(
                        label: "Framework",
                        value: "Transformers",
                        systemImageName: "gear"
                    ),
                    MetadataItem(
                        label: "License",
                        value: "MIT License",
                        systemImageName: "document.fill",
                        url: URL(string: "https://opensource.org/licenses/MIT")
                    )
                ]
            )
        }

        private var emptySection: some View {
            MetadataSection(title: "Empty Section", items: [])
        }

        private var cardDataSection: some View {
            MetadataSection.fromCardData(
                title: "Model Details",
                cardData: ModelCardData(
                    license: "apache-2.0",
                    baseModel: ["microsoft/DialoGPT-medium"],
                    pipelineTag: "text-generation",
                    libraryName: "transformers",
                    language: ["en", "es", "fr"],
                    datasets: ["conversational_dataset", "dialogue_corpus"]
                )
            )
        }
    }
#endif
