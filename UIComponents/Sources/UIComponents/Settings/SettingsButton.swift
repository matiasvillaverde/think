import SwiftUI

public struct SettingsButton: View {
    private enum Constants {
        static let backgroundOpacity: Double = 1.0
        static let hoverBackgroundOpacity: Double = 0.8
        static let hoverOpacity: Double = 0.9
        static let cornerRadius: CGFloat = 8
        static let buttonVerticalPadding: CGFloat = 8
        static let buttonHorizontalPadding: CGFloat = 12
        static let lineLimit: Int = 1
    }

    @State private var isHovered: Bool = false
    @State private var showingSettings: Bool = false

    public var body: some View {
        #if os(iOS) || os(visionOS)
            Button {
                showingSettings = true
            } label: {
                buttonContent
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showingSettings) {
                NavigationView {
                    SettingsView()
                        .navigationTitle(String(
                            localized: "Settings",
                            bundle: .module,
                            comment: "Settings window title"
                        ))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(String(
                                    localized: "Done",
                                    bundle: .module,
                                    comment: "Button to dismiss settings"
                                )) {
                                    showingSettings = false
                                }
                            }
                        }
                }
            }
        #else
            SettingsLink {
                buttonContent
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                isHovered = hovering
            }
        #endif
    }

    private var buttonContent: some View {
        HStack {
            Image(systemName: "gear")
                .imageScale(.medium)
                .foregroundColor(.white)
                .accessibility(label: Text("Settings icon", bundle: .module))
            Text(String(
                localized: "Settings",
                bundle: .module,
                comment: "Button label for settings"
            ))
            .lineLimit(Constants.lineLimit)
        }
        .font(.body)
        .padding(.vertical, Constants.buttonVerticalPadding)
        .padding(.horizontal, Constants.buttonHorizontalPadding)
        .frame(maxWidth: .infinity)
        .background(
            isHovered
                ? Color.marketingSecondary.opacity(Constants.hoverOpacity)
                : Color.marketingSecondary
        )
        .foregroundColor(.white)
        .cornerRadius(Constants.cornerRadius)
    }
}

#if DEBUG
    #Preview {
        SettingsButton()
            .frame(width: 300)
    }
#endif
