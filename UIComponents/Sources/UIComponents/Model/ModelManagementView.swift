import Abstractions
import Database
import SwiftUI

#if os(iOS) || os(visionOS)
    /// A view that manages model selection and discovery in a tabbed interface
    internal struct ModelManagementView: View {
        @Bindable var chat: Chat
        @Binding var isPresented: Bool
        @State private var selectedTab: Tab = .local

        enum Tab {
            case remote
            case local
            case openClaw
            case oneClick
        }

        internal init(chat: Chat, isPresented: Binding<Bool>) {
            self.chat = chat
            _isPresented = isPresented
        }

        internal var body: some View {
            TabView(selection: $selectedTab) {
                localTab
                remoteModelsTab
                openClawTab
                oneClickTab
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("NavigateToMyModels")
                )
            ) { _ in
                selectedTab = .local
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("SwitchToDiscoveryTab")
                )
            ) { _ in
                selectedTab = .local
            }
        }

        // MARK: - Private Views

        private var localTab: some View {
            NavigationStack {
                LocalModelsHubView(chat: chat)
                    .navigationTitle(Text("Local Models", bundle: .module))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(String(localized: "Done", bundle: .module)) {
                                isPresented = false
                            }
                        }
                    }
            }
            .tabItem {
                Label {
                    Text("Local", bundle: .module)
                } icon: {
                    Image(systemName: "laptopcomputer")
                        .accessibilityHidden(true)
                }
            }
            .tag(Tab.local)
        }

        private var remoteModelsTab: some View {
            NavigationStack {
                RemoteModelsView(chat: chat)
                    .navigationTitle(Text("Remote Models", bundle: .module))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(String(localized: "Done", bundle: .module)) {
                                isPresented = false
                            }
                        }
                    }
            }
            .tabItem {
                Label {
                    Text("Remote", bundle: .module)
                } icon: {
                    Image(systemName: "globe")
                        .accessibilityHidden(true)
                }
            }
            .tag(Tab.remote)
        }

        private var openClawTab: some View {
            NavigationStack {
                OpenClawSetupView()
                    .navigationTitle(Text("OpenClaw", bundle: .module))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(String(localized: "Done", bundle: .module)) {
                                isPresented = false
                            }
                        }
                    }
            }
            .tabItem {
                Label {
                    Text("OpenClaw", bundle: .module)
                } icon: {
                    Image(systemName: "link")
                        .accessibilityHidden(true)
                }
            }
            .tag(Tab.openClaw)
        }

        private var oneClickTab: some View {
            NavigationStack {
                OneClickSetupView()
                    .navigationTitle(Text("One-Click", bundle: .module))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(String(localized: "Done", bundle: .module)) {
                                isPresented = false
                            }
                        }
                    }
            }
            .tabItem {
                Label {
                    Text("One-Click", bundle: .module)
                } icon: {
                    Image(systemName: "wand.and.stars")
                        .accessibilityHidden(true)
                }
            }
            .tag(Tab.oneClick)
        }
    }

    #if DEBUG
        #Preview {
            @Previewable @State var isPresented: Bool = true
            @Previewable @State var chat: Chat = Chat.preview

            ModelManagementView(chat: chat, isPresented: $isPresented)
        }
    #endif
#endif

private struct LocalModelsHubView: View {
    @Bindable var chat: Chat

    private enum Mode: String, CaseIterable, Identifiable {
        case myModels = "local_my_models"
        case discover = "local_discover"

        var id: String { rawValue }
        var title: String {
            switch self {
            case .myModels:
                return String(localized: "My Models", bundle: .module)

            case .discover:
                return String(localized: "Discover", bundle: .module)
            }
        }
    }

    private enum Layout {
        static let stackSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
    }

    @State private var mode: Mode = .myModels

    var body: some View {
        VStack(spacing: Layout.stackSpacing) {
            Picker(String(localized: "Local mode", bundle: .module), selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Layout.horizontalPadding)

            Group {
                switch mode {
                case .myModels:
                    MyModelsView(chat: chat)

                case .discover:
                    DiscoveryCarouselView()
                        .navigationDestination(for: DiscoveredModel.self) { model in
                            DiscoveryModelDetailView(model: model)
                        }
                }
            }
        }
        .background(Color.backgroundPrimary)
    }
}

private struct OneClickSetupView: View {
    private enum Layout {
        static let cornerRadius: CGFloat = 18
        static let strokeOpacity: Double = 0.18
        static let spacing: CGFloat = 16
        static let padding: CGFloat = 16
        static let innerSpacing: CGFloat = 10
        static let outerPadding: CGFloat = 16
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            card
            Spacer()
        }
        .padding(Layout.outerPadding)
        .background(Color.backgroundPrimary)
    }

    private var card: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.cornerRadius)
                        .stroke(Color.textSecondary.opacity(Layout.strokeOpacity), lineWidth: 1)
                )

            cardContent
                .padding(Layout.padding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: Layout.innerSpacing) {
            HStack(spacing: Layout.innerSpacing) {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundStyle(Color.marketingSecondary)
                    .accessibilityHidden(true)

                Text("One-Click Setup", bundle: .module)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Text(
                """
                One-click setup will provision and manage your stack for $50/month. Coming soon.
                """,
                bundle: .module
            )
            .font(.callout)
            .foregroundStyle(Color.textSecondary)

            Button {
                // Coming soon.
            } label: {
                Text("Notify Me", bundle: .module)
            }
            .buttonStyle(.borderedProminent)
            .disabled(true)
        }
    }
}
