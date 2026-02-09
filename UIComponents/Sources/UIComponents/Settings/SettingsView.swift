import Abstractions
import Database
import SwiftData
import SwiftUI

// swiftlint:disable type_body_length

// **MARK: - Settings View**
public struct SettingsView: View {
    // **MARK: - Constants**
    enum Constants {
        static let minWidth: CGFloat = 500
        static let minHeight: CGFloat = 400
        static let contentPadding: CGFloat = 16
        static let titleSpacing: CGFloat = 8
        static let sectionSpacing: CGFloat = 24
        static let actionSpacing: CGFloat = 12
        static let compactSpacing: CGFloat = 8
        static let tightSpacing: CGFloat = 4
        static let cornerRadius: CGFloat = 8
        static let bugReportDelay: TimeInterval = 0.1
        static let deleteAnimationDelay: TimeInterval = 0.3
        static let automationListMinHeight: CGFloat = 200
        static let portFieldWidth: CGFloat = 120
        static let progressScale: CGFloat = 0.8
        static let backgroundOpacity: CGFloat = 1.0
        static let hoverBackgroundOpacity: CGFloat = 0.8
        static let hoverOpacity: CGFloat = 0.9
        static let disabledBackgroundOpacity: CGFloat = 0.3
    }

    public init() {
        // Must be public
    }

    @Environment(\.chatViewModel)
    private var chatViewModel: ChatViewModeling

    @Environment(\.reviewPromptViewModel)
    var reviewPromptViewModel: ReviewPromptManaging

    @Environment(\.database)
    var database: DatabaseProtocol

    @Environment(\.audioViewModel)
    var audioViewModel: AudioViewModeling

    @Environment(\.nodeModeViewModel)
    var nodeModeViewModel: NodeModeViewModeling

    @Query(sort: \Chat.createdAt, order: .reverse)
    private var chats: [Chat]

    @Query(sort: \AutomationSchedule.createdAt, order: .reverse)
    var schedules: [AutomationSchedule]

    @State private var isRatingsViewPresented: Bool = true
    @State private var showingDeleteAllAlert: Bool = false
    @State private var showingEmailAlert: Bool = false
    @State private var isReportingBug: Bool = false
    @State private var isPerformingDelete: Bool = false
    @State private var isReportBugHovered: Bool = false
    @State private var isDeleteAllHovered: Bool = false

    @State private var talkModeEnabled: Bool = false
    @State private var wakeWordEnabled: Bool = true
    @State private var wakePhrase: String = ""

    @State private var nodeModeEnabled: Bool = false
    @State private var nodeModePort: String = "9876"
    @State private var nodeModeAuthToken: String = ""
    @State private var nodeModeRunning: Bool = false

    // **MARK: - Body**
    public var body: some View {
        tabsView
        .scenePadding()
        #if os(iOS)
            .frame(minHeight: Constants.minHeight)
        #else
            .frame(minWidth: Constants.minWidth, minHeight: Constants.minHeight)
        #endif
            .alert(isPresented: $showingEmailAlert) {
                emailAlert
            }
            .alert(
                String(
                    localized: "Delete All Data?",
                    bundle: .module,
                    comment: "Title for delete all data confirmation alert"
                ),
                isPresented: $showingDeleteAllAlert,
                actions: deleteAlertActions,
                message: deleteAlertMessage
            )
    }

    var ratingsViewPresented: Bool { isRatingsViewPresented }
    var ratingsViewPresentedBinding: Binding<Bool> { $isRatingsViewPresented }
    var talkModeEnabledValue: Bool {
        get { talkModeEnabled }
        nonmutating set { talkModeEnabled = newValue }
    }
    var talkModeEnabledBinding: Binding<Bool> { $talkModeEnabled }
    var wakeWordEnabledValue: Bool {
        get { wakeWordEnabled }
        nonmutating set { wakeWordEnabled = newValue }
    }
    var wakeWordEnabledBinding: Binding<Bool> { $wakeWordEnabled }
    var wakePhraseValue: String {
        get { wakePhrase }
        nonmutating set { wakePhrase = newValue }
    }
    var wakePhraseBinding: Binding<String> { $wakePhrase }
    var nodeModeEnabledValue: Bool {
        get { nodeModeEnabled }
        nonmutating set { nodeModeEnabled = newValue }
    }
    var nodeModeEnabledBinding: Binding<Bool> { $nodeModeEnabled }
    var nodeModePortValue: String {
        get { nodeModePort }
        nonmutating set { nodeModePort = newValue }
    }
    var nodeModePortBinding: Binding<String> { $nodeModePort }
    var nodeModeAuthTokenValue: String {
        get { nodeModeAuthToken }
        nonmutating set { nodeModeAuthToken = newValue }
    }
    var nodeModeAuthTokenBinding: Binding<String> { $nodeModeAuthToken }
    var nodeModeRunningValue: Bool {
        get { nodeModeRunning }
        nonmutating set { nodeModeRunning = newValue }
    }

    // MARK: - Delete Alert

    @ViewBuilder
    private func deleteAlertActions() -> some View {
        Button(
            String(localized: "Cancel", bundle: .module, comment: "Button label"),
            role: .cancel
        ) {
            showingDeleteAllAlert = false
        }

        Button(
            String(localized: "Delete All", bundle: .module, comment: "Button label"),
            role: .destructive
        ) {
            deleteAllChats()
            showingDeleteAllAlert = false
        }
    }

    private func deleteAlertMessage() -> some View {
        Text(
            String(
                // swiftlint:disable:next line_length
                localized: "This action will permanently delete all chats and cannot be undone. Are you sure you want to continue?",
                bundle: .module,
                comment: "Message for delete all data confirmation alert"
            )
        )
    }

    // MARK: - Actions View

    var actionsView: some View {
        VStack(spacing: Constants.sectionSpacing) {
            actionsHeader
            actionsButtons
            Spacer()
        }
    }

    private var actionsHeader: some View {
        Text(String(
            localized: "Actions",
            bundle: .module,
            comment: "Actions section title"
        ))
        .font(.title2)
        .fontWeight(.bold)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Constants.contentPadding)
        .padding(.top, Constants.contentPadding)
    }

    private var actionsButtons: some View {
        VStack(spacing: Constants.actionSpacing) {
            reportBugButton
            deleteAllDataButton
        }
        .padding(.horizontal, Constants.contentPadding)
    }

    private var reportBugButton: some View {
        Button {
            handleReportBug()
        } label: {
            HStack {
                Image(systemName: "ladybug.fill")
                    .imageScale(.medium)
                    .foregroundColor(.white)
                    .accessibility(label: Text("Bug icon", bundle: .module))
                Text(String(
                    localized: "Report Bug",
                    bundle: .module,
                    comment: "Button label for reporting a bug"
                ))
                .foregroundColor(.white)
                .fontWeight(.medium)
                Spacer()
                if isReportingBug {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(Constants.progressScale)
                }
            }
            .padding()
            .background(
                isReportBugHovered
                    ? Color.marketingSecondary.opacity(Constants.hoverOpacity)
                    : Color.marketingSecondary
            )
            .cornerRadius(Constants.cornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isReportingBug)
        .onHover { hovering in
            isReportBugHovered = hovering
        }
    }

    private var deleteAllDataButton: some View {
        Button {
            handleDeleteAll()
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                    .imageScale(.medium)
                    .foregroundColor(chats.isEmpty ? .gray : .white)
                    .accessibility(label: Text("Delete icon", bundle: .module))
                Text(String(
                    localized: "Delete All Data",
                    bundle: .module,
                    comment: "Button label for deleting all data"
                ))
                .foregroundColor(chats.isEmpty ? .gray : .white)
                .fontWeight(.medium)
                Spacer()
                if isPerformingDelete {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(Constants.progressScale)
                }
            }
            .padding()
            .background(
                chats.isEmpty
                    ? Color.paletteGray.opacity(Constants.disabledBackgroundOpacity)
                    : (isDeleteAllHovered ? Color.paletteRed.opacity(Constants.hoverOpacity) : Color.paletteRed)
            )
            .cornerRadius(Constants.cornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(chats.isEmpty || isPerformingDelete)
        .onHover { hovering in
            if !chats.isEmpty {
                isDeleteAllHovered = hovering
            }
        }
    }

    // MARK: - Legal View

    var legalView: some View {
        TabView {
            TermsOfUseView()
                .tabItem {
                    Label(
                        String(
                            localized: "Terms & Conditions",
                            bundle: .module,
                            comment: "Tab label for Terms of Use"
                        ),
                        systemImage: "doc.text"
                    )
                }

            PrivacyPolicyView()
                .tabItem {
                    Label(
                        String(
                            localized: "Privacy Policy",
                            bundle: .module,
                            comment: "Tab label for Privacy Policy"
                        ),
                        systemImage: "lock.shield"
                    )
                }
        }
        #if os(macOS)
        .tabViewStyle(DefaultTabViewStyle())
        #endif
    }

    private var emailAlert: Alert {
        Alert(
            title: Text(String(
                localized: "Cannot Send Email",
                bundle: .module,
                comment: "Alert title when email cannot be sent"
            )),
            message: Text(String(
                localized: "Your device is not configured to send email.",
                bundle: .module,
                comment: "Alert message when email cannot be sent"
            )),
            dismissButton: .default(Text(String(
                localized: "OK",
                bundle: .module,
                comment: "Button to dismiss alert"
            )))
        )
    }

    // MARK: - Actions

    private func handleReportBug() {
        guard !isReportingBug else {
            return
        }
        isReportingBug = true

        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.bugReportDelay) {
            let success: Bool = BugReporter.sendBugReport()
            if !success {
                showingEmailAlert = true
            }
            isReportingBug = false
        }
    }

    private func handleDeleteAll() {
        guard !isPerformingDelete else {
            return
        }
        showingDeleteAllAlert = true
    }

    private func deleteAllChats() {
        guard !isPerformingDelete else {
            return
        }
        isPerformingDelete = true

        Task {
            await chatViewModel.deleteAll()
            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.deleteAnimationDelay) {
                isPerformingDelete = false
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        SettingsView()
    }
#endif

// swiftlint:enable type_body_length
