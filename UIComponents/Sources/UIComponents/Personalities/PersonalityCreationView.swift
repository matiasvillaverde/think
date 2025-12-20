import Abstractions
import Database
import PhotosUI
import SwiftUI

// MARK: - Constants

private enum Constants {
    static let minInstructionLength: Int = 10
    static let maxInstructionLength: Int = 5_000
    static let minTextEditorHeight: CGFloat = 100
    static let maxTextEditorHeight: CGFloat = 200
    static let progressViewScale: CGFloat = 1.5
    static let overlayOpacity: CGFloat = 0.3
    static let imageSizeLimitMB: Int = 5
}

/// View for creating custom personalities
internal struct PersonalityCreationView: View {
    // MARK: - Properties

    @Binding var isPresented: Bool
    @StateObject private var viewModel: PersonalityCreationViewModel

    // MARK: - Initialization

    internal init(
        isPresented: Binding<Bool>,
        chatViewModel: ChatViewModeling
    ) {
        _isPresented = isPresented
        _viewModel = StateObject(
            wrappedValue: PersonalityCreationViewModel(chatViewModel: chatViewModel)
        )
    }

    // MARK: - Body

    internal var body: some View {
        NavigationStack {
            navigationContent
        }
    }

    private var navigationContent: some View {
        formContent
            .navigationTitle(String(localized: "Create Personality", bundle: .module))
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                #if os(macOS)
                    ToolbarItem(placement: .automatic) {
                        Button(String(localized: "Cancel", bundle: .module)) {
                            isPresented = false
                        }
                    }
                    ToolbarItem(placement: .automatic) {
                        createButton
                    }
                #else
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(String(localized: "Cancel", bundle: .module)) {
                            isPresented = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        createButton
                    }
                #endif
            }
            .disabled(viewModel.isCreating)
            .overlay {
                if viewModel.isCreating {
                    loadingOverlay
                }
            }
            .alert(
                String(localized: "Error", bundle: .module),
                isPresented: .constant(viewModel.validationError != nil)
            ) {
                Button(String(localized: "OK", bundle: .module)) {
                    viewModel.validationError = nil
                }
            } message: {
                Text(viewModel.validationError ?? "")
            }
            .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
                if shouldDismiss {
                    isPresented = false
                }
            }
    }

    private var formContent: some View {
        Form {
            nameSection
            descriptionSection
            instructionSection
            categorySection
            imageSection
        }
    }

    // MARK: - Form Sections

    private var nameSection: some View {
        Section {
            TextField(
                String(localized: "Personality Name", bundle: .module),
                text: $viewModel.name
            )
            .textFieldStyle(.roundedBorder)
        } header: {
            Text("Name", bundle: .module)
        } footer: {
            Text("Give your personality a unique name", bundle: .module)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var descriptionSection: some View {
        Section {
            TextField(
                String(localized: "Brief Description", bundle: .module),
                text: $viewModel.description
            )
            .textFieldStyle(.roundedBorder)
        } header: {
            Text("Description", bundle: .module)
        } footer: {
            Text("Describe what makes this personality unique", bundle: .module)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var instructionSection: some View {
        Section {
            TextEditor(text: $viewModel.systemInstruction)
                .frame(
                    minHeight: Constants.minTextEditorHeight,
                    maxHeight: Constants.maxTextEditorHeight
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignConstants.Radius.small)
                        .stroke(
                            Color.gray.opacity(DesignConstants.Opacity.trackBackground),
                            lineWidth: 1
                        )
                )
        } header: {
            HStack {
                Text("System Instruction", bundle: .module)
                Spacer()
                Text("\(viewModel.systemInstruction.count)/\(Constants.maxInstructionLength)")
                    .font(.caption)
                    .foregroundColor(
                        viewModel.systemInstruction.count > Constants.maxInstructionLength
                            ? .red : .secondary
                    )
            }
        } footer: {
            Text("Define how this personality should behave (10-5000 characters)", bundle: .module)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var categorySection: some View {
        Section {
            Picker(
                String(localized: "Category", bundle: .module),
                selection: $viewModel.selectedCategory
            ) {
                ForEach(PersonalityCategory.allCases, id: \.self) { category in
                    Text(category.displayName)
                        .tag(category as PersonalityCategory)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Category", bundle: .module)
        }
    }

    private var imageSection: some View {
        Section {
            HStack {
                imagePickerButton
                Spacer()
                if viewModel.selectedImage != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .accessibilityHidden(true)
                }
            }

            if viewModel.selectedImage != nil {
                Button(String(localized: "Remove Image", bundle: .module)) {
                    viewModel.selectedImage = nil
                }
                .foregroundColor(.red)
            }
        } header: {
            Text("Image (Optional)", bundle: .module)
        } footer: {
            Text(
                "Add a custom image for your personality (max \(Constants.imageSizeLimitMB)MB)",
                bundle: .module
            )
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    private var imagePickerButton: some View {
        PhotosPicker(
            selection: $viewModel.selectedImage,
            matching: .images
        ) {
            Label(
                String(localized: "Select Image", bundle: .module),
                systemImage: "photo"
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Components

    private var createButton: some View {
        Button(String(localized: "Create", bundle: .module)) {
            Task {
                await viewModel.createPersonality()
            }
        }
        .fontWeight(.semibold)
        .disabled(viewModel.isCreating)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(Constants.overlayOpacity)
                .ignoresSafeArea()

            VStack(spacing: DesignConstants.Spacing.medium) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(Constants.progressViewScale)

                Text("Creating personality...", bundle: .module)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(DesignConstants.Spacing.large)
            .background(.regularMaterial)
            .cornerRadius(DesignConstants.Radius.standard)
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview(traits: .modifier(PreviewDatabase())) {
        @Previewable @State var isPresented: Bool = true
        PersonalityCreationView(
            isPresented: $isPresented,
            chatViewModel: PreviewChatViewModel()
        )
    }
#endif
