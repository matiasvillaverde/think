import Abstractions
import Foundation
import SwiftUI

internal struct RemoteModelsModelsSection: View {
    let providerName: String
    let isKeyConfigured: Bool
    let isLoading: Bool
    let errorMessage: String?
    let searchText: String

    let models: [RemoteModel]
    let freeModels: [RemoteModel]
    let paidModels: [RemoteModel]
    let otherModels: [RemoteModel]

    let isSelectingModel: Bool
    let isSelected: (RemoteModel) -> Bool
    let onSelect: (RemoteModel) -> Void
    let onRetry: () -> Void
    let onShowKeyEntry: () -> Void

    var body: some View {
        Section {
            content
        } header: {
            Text("Models", bundle: .module)
        }
    }

    @ViewBuilder private var content: some View {
        if !isKeyConfigured {
            RemoteModelsKeyRequiredView(providerName: providerName) {
                onShowKeyEntry()
            }
        } else if isLoading, models.isEmpty {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else if let errorMessage, models.isEmpty {
            ContentUnavailableView(
                String(localized: "Unable to Load Models", bundle: .module),
                systemImage: "exclamationmark.triangle.fill",
                description: Text(errorMessage)
            )

            Button(action: onRetry) {
                Label {
                    Text("Retry", bundle: .module)
                } icon: {
                    Image(systemName: "arrow.clockwise")
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.borderedProminent)
        } else if models.isEmpty {
            ContentUnavailableView(
                String(localized: "No Models Found", bundle: .module),
                systemImage: "sparkles",
                description: Text(
                    "Try a different provider or adjust your search.",
                    bundle: .module
                )
            )
        } else {
            if let errorMessage {
                nonBlockingErrorBanner(errorMessage)
            }

            modelRows
        }
    }

    private func nonBlockingErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: DesignConstants.Spacing.standard) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.paletteOrange)
                .accessibilityHidden(true)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
            Spacer(minLength: 0)
            Button(action: onRetry) {
                Text("Retry", bundle: .module)
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder private var modelRows: some View {
        if !freeModels.isEmpty {
            pricingHeader(String(localized: "Free Models", bundle: .module))
            ForEach(freeModels) { model in
                RemoteModelRow(
                    model: model,
                    isSelected: isSelected(model),
                    isSelecting: isSelectingModel
                ) { onSelect(model) }
            }
        }

        if !paidModels.isEmpty {
            pricingHeader(String(localized: "Paid Models", bundle: .module))
            ForEach(paidModels) { model in
                RemoteModelRow(
                    model: model,
                    isSelected: isSelected(model),
                    isSelecting: isSelectingModel
                ) { onSelect(model) }
            }
        }

        if !otherModels.isEmpty {
            pricingHeader(String(localized: "Other Models", bundle: .module))
            ForEach(otherModels) { model in
                RemoteModelRow(
                    model: model,
                    isSelected: isSelected(model),
                    isSelecting: isSelectingModel
                ) { onSelect(model) }
            }
        }
    }

    private func pricingHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(Color.textSecondary)
            .textCase(.uppercase)
            .padding(.top, RemoteModelsViewConstants.sectionHeaderTopPadding)
    }
}
