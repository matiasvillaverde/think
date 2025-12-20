import Abstractions
import SwiftUI

extension DiscoveryCarouselView {
    var bestForDeviceSection: some View {
        Group {
            if isLoadingBest {
                sectionLoadingView(title: "Best for Your Device")
            } else if let error = bestError {
                sectionErrorView(error, section: "Best for Your Device") {
                    Task { await loadBestModel() }
                }
            } else if let model = bestModel,
                selectedFilter.matches(model) {
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.large) {
                    sectionHeader(
                        title: "Best for Your Device",
                        subtitle: "Highest quality that fits your memory",
                        systemImage: "star.circle.fill"
                    )

                    HStack(spacing: DesignConstants.Spacing.large) {
                        NavigationLink(value: model) {
                            DiscoveryModelCard(model: model)
                        }
                        .buttonStyle(DiscoveryModelCardButtonStyle())
                    }
                    .padding(.horizontal, DesignConstants.Spacing.large)
                }
            }
        }
    }

    var trendingSection: some View {
        Group {
            if isLoadingTrending {
                sectionLoadingView(title: "Trending")
            } else if let error = trendingError {
                sectionErrorView(error, section: "Trending") {
                    Task { await loadTrendingModels() }
                }
            } else if !filteredTrendingModels.isEmpty {
                modelGridSection(
                    title: "Trending",
                    subtitle: "Hot right now on Hugging Face",
                    systemImage: "flame.fill",
                    models: filteredTrendingModels
                )
            }
        }
    }

    var latestSection: some View {
        Group {
            if isLoadingLatest {
                sectionLoadingView(title: "Latest Updates")
            } else if let error = latestError {
                sectionErrorView(error, section: "Latest Updates") {
                    Task { await loadLatestModels() }
                }
            } else if !filteredLatestModels.isEmpty {
                modelGridSection(
                    title: "Latest Updates",
                    subtitle: "Recently updated models",
                    systemImage: "clock.fill",
                    models: filteredLatestModels
                )
            }
        }
    }

    private var filteredTrendingModels: [DiscoveredModel] {
        trendingModels.filter { selectedFilter.matches($0) }
    }

    private var filteredLatestModels: [DiscoveredModel] {
        latestModels.filter { selectedFilter.matches($0) }
    }

    private func sectionLoadingView(title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            Text(title, bundle: .module)
                .font(.title2)
                .bold()
                .foregroundColor(.textPrimary)
                .padding(.horizontal, DesignConstants.Spacing.large)

            ProgressView()
                .progressViewStyle(.circular)
                .padding(.horizontal, DesignConstants.Spacing.large)
        }
    }

    private func sectionHeader(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.marketingSecondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
                Text(title, bundle: .module)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.textPrimary)

                Text(subtitle, bundle: .module)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, DesignConstants.Spacing.large)
    }

    private func modelGridSection(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        systemImage: String,
        models: [DiscoveredModel]
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.large) {
            sectionHeader(title: title, subtitle: subtitle, systemImage: systemImage)

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: DiscoveryConstants.Card.width),
                        spacing: DesignConstants.Spacing.large
                    )
                ],
                spacing: DesignConstants.Spacing.large
            ) {
                ForEach(models) { model in
                    NavigationLink(value: model) {
                        DiscoveryModelCard(model: model)
                    }
                    .buttonStyle(DiscoveryModelCardButtonStyle())
                }
            }
            .padding(.horizontal, DesignConstants.Spacing.large)
        }
    }

    func loadBestModel() async {
        isLoadingBest = true
        bestError = nil
        bestModel = await viewModel.bestModelForDevice()
        isLoadingBest = false
    }

    func loadTrendingModels() async {
        isLoadingTrending = true
        trendingError = nil

        do {
            trendingModels = try await viewModel.trendingModels(limit: Constants.trendingLimit)
        } catch {
            trendingError = error
        }

        isLoadingTrending = false
    }

    func loadLatestModels() async {
        isLoadingLatest = true
        latestError = nil

        do {
            latestModels = try await viewModel.latestModels(limit: Constants.latestLimit)
        } catch {
            latestError = error
        }

        isLoadingLatest = false
    }
}
