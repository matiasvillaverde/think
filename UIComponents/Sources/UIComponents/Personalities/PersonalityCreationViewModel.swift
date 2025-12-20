import Abstractions
import Database
import Foundation
import PhotosUI
import SwiftUI

/// Temporary stub implementation for PersonalityCreationViewModel
/// This is a placeholder to allow UIComponents to compile
@MainActor
internal final class PersonalityCreationViewModel: ObservableObject {
    private enum Constants {
        static let sleepDuration: UInt64 = 500_000_000
    }

    @Published var name: String = ""
    @Published var description: String = ""
    @Published var systemInstruction: String = ""
    @Published var selectedCategory: PersonalityCategory = .personal
    @Published var selectedImage: PhotosPickerItem?
    @Published var isCreating: Bool = false
    @Published var validationError: String?
    @Published var shouldDismiss: Bool = false

    private let chatViewModel: ChatViewModeling

    init(chatViewModel: ChatViewModeling) {
        self.chatViewModel = chatViewModel
    }

    deinit {
        // Required by linter
    }

    func createPersonality() async {
        // Stub implementation
        isCreating = true
        defer { isCreating = false }

        // Basic validation
        guard !name.isEmpty else {
            validationError = "Name is required"
            return
        }

        guard !systemInstruction.isEmpty else {
            validationError = "System instruction is required"
            return
        }

        // In a real implementation, this would create the personality
        // For now, just dismiss after a short delay
        try? await Task.sleep(nanoseconds: Constants.sleepDuration)
        shouldDismiss = true
    }
}
