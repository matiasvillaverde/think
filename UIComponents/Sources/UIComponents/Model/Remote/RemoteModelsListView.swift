import Abstractions
import SwiftUI

internal struct RemoteModelsListView: View {
    let models: [RemoteModel]
    @Binding var searchText: String
    let isSelectingModel: Bool
    let isSelected: (RemoteModel) -> Bool
    let onSelect: (RemoteModel) -> Void

    var body: some View {
        List {
            if !freeModels.isEmpty {
                sectionHeader("Free Models")
                modelRows(freeModels)
            }
            if !paidModels.isEmpty {
                sectionHeader("Paid Models")
                modelRows(paidModels)
            }
            if !otherModels.isEmpty {
                sectionHeader("Other Models")
                modelRows(otherModels)
            }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, placement: .automatic)
    }

    private var freeModels: [RemoteModel] {
        models.filter { $0.pricing == .free }
    }

    private var paidModels: [RemoteModel] {
        models.filter { $0.pricing == .paid }
    }

    private var otherModels: [RemoteModel] {
        models.filter { $0.pricing == .unknown }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.top, RemoteModelsViewConstants.sectionHeaderTopPadding)
    }

    @ViewBuilder
    private func modelRows(_ models: [RemoteModel]) -> some View {
        ForEach(models) { model in
            RemoteModelRow(
                model: model,
                isSelected: isSelected(model),
                isSelecting: isSelectingModel
            ) {
                onSelect(model)
            }
        }
    }
}

#if DEBUG
#Preview {
    RemoteModelsListView(
        models: [],
        searchText: .constant(""),
        isSelectingModel: false,
        isSelected: { _ in false },
        onSelect: { _ in _ = 0 }
    )
}
#endif
