import Abstractions
import Database
import Foundation
import SwiftUI

// MARK: - Constants

private enum PersonalityDetailConstants {
    static let soulPreviewLines: Int = 5
    static let progressViewScale: CGFloat = 1.5
    static let overlayOpacity: CGFloat = 0.3
    static let sleepDuration: UInt64 = 500_000_000
}

/// View for displaying personality details with edit and delete options
internal struct PersonalityDetailView: View {
    // MARK: - Properties

    @Binding var isPresented: Bool
    @State private var showingEditSheet: Bool = false
    @State private var showingDeleteConfirmation: Bool = false
    @State private var isDeleting: Bool = false
    @State private var deleteError: String?

    let personality: Personality
    private let chatViewModel: ChatViewModeling

    // MARK: - Initialization

    internal init(
        isPresented: Binding<Bool>,
        personality: Personality,
        chatViewModel: ChatViewModeling
    ) {
        _isPresented = isPresented
        self.personality = personality
        self.chatViewModel = chatViewModel
    }

    // MARK: - Body

    internal var body: some View {
        NavigationStack {
            navigationContent
        }
    }

    private var navigationContent: some View {
        scrollContent
            .navigationTitle(personality.name)
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                #if os(macOS)
                ToolbarItem(placement: .automatic) {
                    Button(String(localized: "Done", bundle: .module)) { isPresented = false }
                }
                ToolbarItem(placement: .automatic) { editButton }
                #else
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "Done", bundle: .module)) { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) { editButton }
                #endif
            }
            .sheet(isPresented: $showingEditSheet) {
                PersonalityEditView(
                    isPresented: $showingEditSheet,
                    personality: personality,
                    chatViewModel: chatViewModel
                )
            }
            .confirmationDialog(
                String(localized: "Delete Personality", bundle: .module),
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                deleteConfirmationButtons
            } message: {
                Text("This action cannot be undone.", bundle: .module)
            }
            .alert(
                String(localized: "Error", bundle: .module),
                isPresented: .constant(deleteError != nil)
            ) {
                Button(String(localized: "OK", bundle: .module)) { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
            .disabled(isDeleting)
            .overlay { if isDeleting { loadingOverlay } }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.large) {
                headerSection
                descriptionSection
                categorySection
                soulSection
                if personality.isDeletable { deleteSection }
            }
            .padding()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: DesignConstants.Spacing.large) {
            personalityImage
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
                Text(personality.name).font(.title2).fontWeight(.semibold)
                if personality.isCustom { customBadge }
                if personality.isFeature { featuredBadge }
            }
            Spacer()
        }
    }

    private var personalityImage: some View {
        PersonalityImageView(personality: personality)
    }

    private var customBadge: some View {
        Text("Custom", bundle: .module)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, DesignConstants.Spacing.medium)
            .padding(.vertical, DesignConstants.Spacing.xSmall)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(DesignConstants.Opacity.trackBackground))
            )
    }

    private var featuredBadge: some View {
        Text("Featured", bundle: .module)
            .font(.caption)
            .foregroundColor(.accentColor)
            .padding(.horizontal, DesignConstants.Spacing.medium)
            .padding(.vertical, DesignConstants.Spacing.xSmall)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(DesignConstants.Opacity.trackBackground))
            )
    }

    // MARK: - Content Sections

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            Text("Description", bundle: .module)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(personality.displayDescription)
                .font(.body)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            Text("Category", bundle: .module)
                .font(.headline)
                .foregroundColor(.secondary)
            HStack {
                Image(systemName: personality.category.iconName)
                    .foregroundColor(personality.tintColor)
                    .accessibilityHidden(true)
                Text(personality.category.displayName)
                    .font(.body)
            }
        }
    }

    private var soulSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            Text("Soul", bundle: .module)
                .font(.headline)
                .foregroundColor(.secondary)
            if let soul: Memory = personality.soul, !soul.content.isEmpty {
                Text(soul.content)
                    .font(.body)
                    .lineLimit(PersonalityDetailConstants.soulPreviewLines)
                    .foregroundColor(.primary)
            } else {
                Text("No soul defined. Edit to add personality identity.", bundle: .module)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            Divider()
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .accessibilityHidden(true)
                    Text("Delete Personality", bundle: .module)
                }
            }
            .foregroundColor(.red)
        }
        .padding(.top, DesignConstants.Spacing.large)
    }

    // MARK: - Components

    private var editButton: some View {
        Button { showingEditSheet = true } label: { Text("Edit", bundle: .module) }
    }

    private var deleteConfirmationButtons: some View {
        Group {
            Button(String(localized: "Delete", bundle: .module), role: .destructive) {
                Task { await deletePersonality() }
            }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {
                // Cancel action - dismiss dialog
            }
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(PersonalityDetailConstants.overlayOpacity)
                .ignoresSafeArea()
            VStack(spacing: DesignConstants.Spacing.medium) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(PersonalityDetailConstants.progressViewScale)
                Text("Deleting...", bundle: .module)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(DesignConstants.Spacing.large)
            .background(.regularMaterial)
            .cornerRadius(DesignConstants.Radius.standard)
        }
    }

    // MARK: - Actions

    private func deletePersonality() async {
        isDeleting = true
        defer { isDeleting = false }
        try? await Task.sleep(nanoseconds: PersonalityDetailConstants.sleepDuration)
        isPresented = false
    }
}

// MARK: - Subviews

internal struct PersonalityImageView: View {
    private enum Constants {
        static let imageSize: CGFloat = 80
    }

    let personality: Personality

    var body: some View {
        imageContent
            .frame(width: Constants.imageSize, height: Constants.imageSize)
            .clipShape(Circle())
    }

    @ViewBuilder private var imageContent: some View {
        if let customImage = personality.customImage {
            customImageView(customImage)
        } else if let imageName = personality.imageName {
            Image(imageName, bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityLabel(Text(personality.name))
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .foregroundColor(personality.tintColor)
                .accessibilityLabel(Text(personality.name))
        }
    }

    @ViewBuilder
    private func customImageView(_ customImage: ImageAttachment) -> some View {
        if let platformImage = platformImage(from: customImage.image) {
            #if os(macOS)
            Image(nsImage: platformImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityLabel(Text(personality.name))
            #else
            Image(uiImage: platformImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityLabel(Text(personality.name))
            #endif
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .foregroundColor(personality.tintColor)
                .accessibilityLabel(Text(personality.name))
        }
    }

    #if os(macOS)
    private func platformImage(from data: Data) -> NSImage? {
        NSImage(data: data)
    }
    #else
    private func platformImage(from data: Data) -> UIImage? {
        UIImage(data: data)
    }
    #endif
}

// MARK: - Preview

#if DEBUG
#Preview(traits: .modifier(PreviewDatabase())) {
    @Previewable @State var isPresented: Bool = true
    PersonalityDetailView(
        isPresented: $isPresented,
        personality: Personality.preview,
        chatViewModel: PreviewChatViewModel()
    )
}
#endif
