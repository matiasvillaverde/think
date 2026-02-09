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

/// View for editing existing personalities
internal struct PersonalityEditView: View {
    // MARK: - Properties

    @Binding var isPresented: Bool
    @StateObject private var viewModel: PersonalityEditStubViewModel

    // MARK: - Initialization

    internal init(
        isPresented: Binding<Bool>,
        personality: Personality,
        chatViewModel: ChatViewModeling
    ) {
        _isPresented = isPresented
        _viewModel = StateObject(
            wrappedValue: PersonalityEditStubViewModel(
                personality: personality,
                chatViewModel: chatViewModel
            )
        )
    }

    // MARK: - Body

    internal var body: some View {
        NavigationStack {
            navigationContent
        }
        .task {
            await viewModel.loadPersonality()
        }
    }

    private var navigationContent: some View {
        formContent
            .navigationTitle(String(localized: "Edit Personality", bundle: .module))
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
                        saveButton
                    }
                #else
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(String(localized: "Cancel", bundle: .module)) {
                            isPresented = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        saveButton
                    }
                #endif
            }
            .disabled(viewModel.isUpdating || viewModel.isLoading)
            .overlay {
                if viewModel.isUpdating || viewModel.isLoading {
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
            soulSection
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
            Text("The display name for this personality", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
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
            Text("A short description of what this personality does", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
        }
    }

    private var soulSection: some View {
        Section {
            TextEditor(text: $viewModel.soul)
                .frame(
                    minHeight: Constants.minTextEditorHeight,
                    maxHeight: Constants.maxTextEditorHeight
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignConstants.Radius.small)
                        .stroke(
                            Color.paletteGray.opacity(DesignConstants.Opacity.trackBackground),
                            lineWidth: 1
                        )
                )
        } header: {
            Text("Soul (Identity)", bundle: .module)
        } footer: {
            soulFooter
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
                Button(String(localized: "Remove New Image", bundle: .module)) {
                    viewModel.selectedImage = nil
                }
                .foregroundColor(.red)
            }
        } header: {
            Text("Image (Optional)", bundle: .module)
        } footer: {
            Text("Select a new image (max \(Constants.imageSizeLimitMB)MB)", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
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

    private var soulFooter: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.xSmall) {
            Text(
                "Define this personality's core identity, values, and communication style.",
                bundle: .module
            )
            Text(
                "Example: \"I am a thoughtful assistant who values clarity.\"",
                bundle: .module
            )
            .italic()
        }
        .font(.caption)
        .foregroundColor(Color.textSecondary)
    }

    // MARK: - Components

    private var saveButton: some View {
        Button(String(localized: "Save", bundle: .module)) {
            Task {
                await viewModel.updatePersonality()
            }
        }
        .fontWeight(.semibold)
        .disabled(viewModel.isUpdating)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.paletteBlack.opacity(Constants.overlayOpacity)
                .ignoresSafeArea()

            VStack(spacing: DesignConstants.Spacing.medium) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(Constants.progressViewScale)

                Text(
                    viewModel.isLoading ? "Loading..." : "Saving...",
                    bundle: .module
                )
                .font(.headline)
                .foregroundColor(Color.textPrimary)
            }
            .padding(DesignConstants.Spacing.large)
            .background(.regularMaterial)
            .cornerRadius(DesignConstants.Radius.standard)
        }
    }
}

// MARK: - Stub ViewModel

/// Stub implementation for PersonalityEditViewModel within UIComponents
/// This is a placeholder that handles basic UI state for previews and testing
@MainActor
internal final class PersonalityEditStubViewModel: ObservableObject {
    // MARK: - Constants

    private enum Constants {
        static let sleepDuration: UInt64 = 500_000_000
        static let shortSleepDuration: UInt64 = 100_000_000
    }

    // MARK: - Published Properties

    @Published var name: String = ""
    @Published var description: String = ""
    @Published var soul: String = ""
    @Published var systemInstruction: String = ""
    @Published var selectedCategory: PersonalityCategory = .productivity
    @Published var selectedImage: PhotosPickerItem?
    @Published var isLoading: Bool = false
    @Published var isUpdating: Bool = false
    @Published var validationError: String?
    @Published var shouldDismiss: Bool = false

    // MARK: - Private Properties

    private let personality: Personality
    private let chatViewModel: ChatViewModeling

    // MARK: - Initialization

    init(personality: Personality, chatViewModel: ChatViewModeling) {
        self.personality = personality
        self.chatViewModel = chatViewModel
    }

    deinit {
        // Required by linter
    }

    // MARK: - Methods

    func loadPersonality() async {
        isLoading = true
        defer { isLoading = false }

        // Brief delay for UI feedback
        try? await Task.sleep(nanoseconds: Constants.shortSleepDuration)

        // Load data from the personality
        name = personality.name
        description = personality.displayDescription
        selectedCategory = personality.category

        // Load system instruction if custom
        if case .custom(let instruction) = personality.systemInstruction {
            systemInstruction = instruction
        }

        // Load soul from memory
        if let soul: Memory = personality.soul {
            self.soul = soul.content
        }
    }

    func updatePersonality() async {
        // Clear previous error
        validationError = nil

        // Basic validation
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationError = String(localized: "Name cannot be empty", bundle: .module)
            return
        }

        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationError = String(localized: "Description cannot be empty", bundle: .module)
            return
        }

        isUpdating = true
        defer { isUpdating = false }

        // Stub implementation - just dismiss after a short delay
        // Real implementation will be wired through Factories
        try? await Task.sleep(nanoseconds: Constants.sleepDuration)
        shouldDismiss = true
    }
}

// MARK: - Preview

#if DEBUG
    #Preview(traits: .modifier(PreviewDatabase())) {
        @Previewable @State var isPresented: Bool = true
        PersonalityEditView(
            isPresented: $isPresented,
            personality: Personality.preview,
            chatViewModel: PreviewChatViewModel()
        )
    }
#endif
