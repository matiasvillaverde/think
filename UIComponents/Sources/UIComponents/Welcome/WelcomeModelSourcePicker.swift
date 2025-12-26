import SwiftUI

internal struct WelcomeModelSourcePicker: View {
    @Binding var selectedSource: WelcomeView.ModelSource

    var body: some View {
        Picker(
            String(localized: "Model Source", bundle: .module),
            selection: $selectedSource
        ) {
            ForEach(WelcomeView.ModelSource.allCases) { source in
                Text(source.title).tag(source)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}

#if DEBUG
#Preview {
    WelcomeModelSourcePicker(selectedSource: .constant(.local))
        .padding()
}
#endif
