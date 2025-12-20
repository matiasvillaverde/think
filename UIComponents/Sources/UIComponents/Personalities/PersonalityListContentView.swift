// PersonalityListContentView.swift
import Abstractions
import Database
import SwiftData
import SwiftUI

/// More efficient query-based approach for large datasets
internal struct PersonalityListContentView: View {
    @Query(
        filter: #Predicate<Personality> { $0.isCustom == true },
        sort: \Personality.createdAt,
        order: .reverse
    )
    private var customPersonalities: [Personality]

    @Query(
        filter: #Predicate<Personality> { $0.isCustom == false },
        sort: \Personality.createdAt
    )
    private var systemPersonalities: [Personality]

    @Binding var isShowing: Bool
    let onSelectPersonality: (Personality) -> Void

    @Environment(\.chatViewModel)
    private var chatViewModel: ChatViewModeling
    @State private var showPersonalityCreation: Bool = false

    private enum Layout {
        static let minItemWidth: CGFloat = 160
    }

    /// System personalities grouped by category (computed once)
    private var systemPersonalitiesByCategory: [PersonalityCategory: [Personality]] {
        Dictionary(grouping: systemPersonalities, by: \.category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            personalityList
        }
        .toolbar {
            #if os(macOS)
                ToolbarItem(placement: .automatic) {
                    Button("Close") {
                        isShowing = false
                    }
                }
            #else
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        isShowing = false
                    }
                }
            #endif
        }
        .sheet(isPresented: $showPersonalityCreation) {
            PersonalityCreationView(
                isPresented: $showPersonalityCreation,
                chatViewModel: chatViewModel
            )
        }
    }

    private var headerView: some View {
        Text("AI Personalities", bundle: .module)
            .font(.title)
            .fontWeight(.bold)
            .foregroundStyle(Color.textPrimary)
            .padding()
    }

    private var personalityList: some View {
        ScrollView {
            LazyVStack(spacing: DesignConstants.Spacing.huge) {
                // My Personalities section with create card
                myPersonalitiesSection

                // System personalities by category
                ForEach(PersonalityCategory.sortedCases, id: \.self) { category in
                    if let personalities = systemPersonalitiesByCategory[category],
                        !personalities.isEmpty {
                        PersonalityGroupView(
                            personalities: personalities,
                            title: category.displayName,
                            onSelectPersonality: onSelectPersonality
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, DesignConstants.Spacing.huge)
        }
        .scrollIndicators(.visible)
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst) || os(watchOS)
            .scrollDismissesKeyboard(.immediately)
        #endif
    }

    @ViewBuilder private var myPersonalitiesSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
            Text("My Personalities", bundle: .module)
                .font(.title)
                .bold()
                .foregroundColor(Color.textPrimary)
                .padding(.leading, DesignConstants.Spacing.small)

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: Layout.minItemWidth),
                        spacing: DesignConstants.Spacing.medium
                    )
                ],
                spacing: DesignConstants.Spacing.medium
            ) {
                // Create card always shows first
                CreatePersonalityCardView {
                    showPersonalityCreation = true
                }

                // Then custom personalities
                ForEach(customPersonalities) { personality in
                    PersonalityCardView(personality: personality)
                        .onTapGesture {
                            onSelectPersonality(personality)
                        }
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        Spacer()
    }
}

extension PersonalityCategory {
    // swiftlint:disable no_magic_numbers
    /// Priority order for displaying categories
    var displayPriority: Int {
        switch self {
        case .productivity:
            0

        case .creative:
            1

        case .education:
            2

        case .personal:
            3

        case .lifestyle:
            4

        case .health:
            5

        case .entertainment:
            6
        }
    }

    // swiftlint:enable no_magic_numbers

    /// Sorted categories by display priority
    static var sortedCases: [PersonalityCategory] {
        PersonalityCategory.allCases.sorted { $0.displayPriority < $1.displayPriority }
    }
}

#if DEBUG
    #Preview(traits: .modifier(PreviewDatabase())) {
        @Previewable @State var isShowing: Bool = true
        PersonalityListContentView(
            isShowing: $isShowing
        ) { personality in
            print(personality.name)
        }
    }
#endif
