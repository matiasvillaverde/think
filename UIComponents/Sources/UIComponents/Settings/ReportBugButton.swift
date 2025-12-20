import SwiftUI

public struct ReportBugButton: View {
    @Binding var isReportingBug: Bool
    @Binding var showingEmailAlert: Bool

    @State private var isHovered: Bool = false

    private enum Constants {
        static let backgroundOpacity: Double = 0.15
        static let hoverBackgroundOpacity: Double = 0.25
        static let cornerRadius: CGFloat = 8
        static let bugReportDelay: TimeInterval = 0.1
        static let progressViewScale: CGFloat = 0.8
        static let lineLimit: Int = 1
    }

    public var body: some View {
        Button(
            action: {
                guard !isReportingBug else {
                    return
                }

                isReportingBug = true

                // Use DispatchQueue to simulate async operation and handle completion
                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.bugReportDelay) {
                    let success: Bool = BugReporter.sendBugReport()

                    if !success {
                        showingEmailAlert = true
                    }

                    isReportingBug = false
                }
            },
            label: {
                reportBugLabel
                    .background(
                        Color.marketingSecondary.opacity(
                            isHovered
                                ? Constants.hoverBackgroundOpacity : Constants.backgroundOpacity
                        )
                    )
                    .foregroundColor(Color.textSecondary)
                    .cornerRadius(Constants.cornerRadius)
            }
        )
        .buttonStyle(PlainButtonStyle())
        .disabled(isReportingBug)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var reportBugLabel: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                if isReportingBug {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: Color.iconAlert)
                        )
                        .scaleEffect(Constants.progressViewScale)
                        .accessibility(
                            label: Text("Loading indicator", bundle: .module)
                        )
                } else {
                    Image(systemName: "ladybug.fill")
                        .imageScale(.medium)
                        .accessibility(label: Text("Bug icon", bundle: .module))
                }
                Text(String(
                    localized: "Report Bug",
                    bundle: .module,
                    comment: "Button label for reporting a bug"
                ))
                .lineLimit(Constants.lineLimit)
            }
        }
        .font(.body)
    }
}
