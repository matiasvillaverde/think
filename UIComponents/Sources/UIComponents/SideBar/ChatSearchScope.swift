import Foundation

public enum ChatSearchScope: String, CaseIterable, Identifiable {
    // Sorted alphabetically
    case all = "All"
    case messages = "Messages"
    case name = "Title"

    public var id: Self { self }
}
