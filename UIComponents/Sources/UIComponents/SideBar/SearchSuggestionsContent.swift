import SwiftUI

public struct SearchSuggestionsContent: View {
    // MARK: - Properties

    let searchText: String
    let modelSuggestions: [String]

    // MARK: - Body

    public var body: some View {
        let filteredSuggestions: [String] = modelSuggestions.filter { suggestion in
            suggestion.localizedCaseInsensitiveContains(searchText) || searchText.isEmpty
        }

        return Group {
            if !filteredSuggestions.isEmpty {
                Section(
                    String(
                        localized: "Models",
                        bundle: .module,
                        comment: "Title for the list of ai model suggestions in the search bar"
                    )
                ) {
                    ForEach(filteredSuggestions, id: \.self) { suggestion in
                        Text(suggestion).searchCompletion(suggestion)
                    }
                }
            }
        }
    }
}
