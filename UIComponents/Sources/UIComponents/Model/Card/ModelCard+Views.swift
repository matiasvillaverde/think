import Database
import SwiftUI

// MARK: - View Components Extension

extension ModelCard {
    var mainContentSection: some View {
        VStack(spacing: DesignConstants.Spacing.medium) {
            topRowContent
            if !model.tags.isEmpty {
                tagsSection
            }
        }
        .padding(DesignConstants.Spacing.large)
    }

    var topRowContent: some View {
        HStack(spacing: DesignConstants.Spacing.large) {
            ModelInfoSection(model: model, isSelected: isSelectedComputed)
            Spacer()
            analyticsButton
            statusOrActionView
        }
    }

    @ViewBuilder var analyticsButton: some View {
        if model.state?.isDownloaded == true {
            Button {
                handleAnalyticsButtonTap()
            } label: {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityLabel("View Model Analytics")
            }
            .buttonStyle(.plain)
            .help("View Model Analytics")
        }
    }

    @ViewBuilder var statusOrActionView: some View {
        if isSelectedComputed {
            ModelIndicatorView(model: model, chat: chat)
        } else {
            downloadActionView()
        }
    }

    @ViewBuilder var downloadProgressSection: some View {
        if shouldShowProgressBar {
            Divider()
                .opacity(DesignConstants.Opacity.backgroundSubtle)

            ModelCardDownloadSection(
                model: model,
                onPause: handlePauseDownload,
                onResume: handleResumeDownload,
                isCancelConfirmationPresented: isCancelConfirmationPresentedBinding
            )
            .padding(.horizontal, DesignConstants.Spacing.large)
            .padding(.vertical, DesignConstants.Spacing.medium)
        }
    }

    var shouldShowProgressBar: Bool {
        switch model.state {
        case .downloadingActive, .downloadingPaused:
            true

        default:
            false
        }
    }

    var deleteButton: some View {
        Button(role: .destructive) {
            // Trigger delete action - the sheet handles the state
            handleDeleteButtonTap()
        } label: {
            HStack {
                Image(systemName: "trash")
                    .accessibilityHidden(true)
                Text("Delete", bundle: .module)
            }
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    func downloadActionView() -> some View {
        switch model.state {
        case .notDownloaded:
            DownloadButton(
                model: model,
                isConfirmationPresented: isConfirmationPresentedBinding
            )

        case .downloaded:
            switch model.runtimeState {
            case .error:
                StateIndicator(
                    icon: "exclamationmark.circle.fill",
                    text: "Error",
                    color: Color.iconAlert
                )

            case .loading:
                StateIndicator(
                    icon: "progress.indicator",
                    text: "Loading",
                    color: Color.accentColor
                )

            case .generating:
                StateIndicator(
                    icon: "brain.filled.head.profile",
                    text: "Generating",
                    color: Color.paletteGreen
                )

            case .loaded, .notLoaded:
                deleteButton

            case .none:
                deleteButton
            }

        default:
            EmptyView()
        }
    }

    @ViewBuilder var tagsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignConstants.Spacing.small) {
                ForEach(model.tags.sorted(), id: \.self) { tag in
                    TagView(tag: tag)
                }
            }
            .padding(.horizontal, DesignConstants.Spacing.small)
        }
    }
}
