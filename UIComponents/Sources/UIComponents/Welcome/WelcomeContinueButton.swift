import SwiftUI

internal struct WelcomeContinueButton: View {
    let isSaving: Bool
    let isEnabled: Bool
    let onContinue: () async -> Void

    var body: some View {
        Button {
            Task {
                await onContinue()
            }
        } label: {
            Group {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(WelcomeConstants.progressViewScale)
                } else {
                    HStack {
                        Text("Continue", bundle: .module)
                            .fontWeight(.medium)

                        Image(systemName: "arrow.right")
                            .font(.footnote)
                            .accessibilityHidden(true)
                    }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: WelcomeConstants.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: WelcomeConstants.cornerRadiusSmall)
                    .fill(
                        isEnabled
                            ? Color.marketingPrimary
                            : Color.paletteGray.opacity(WelcomeConstants.disabledButtonOpacity)
                    )
            )
        }
        .disabled(!isEnabled || isSaving)
        .padding(.horizontal)
        .padding(.bottom, WelcomeConstants.bottomPadding)
    }
}

#if DEBUG
#Preview {
    WelcomeContinueButton(isSaving: false, isEnabled: true) { _ = () }
        .padding()
}
#endif
