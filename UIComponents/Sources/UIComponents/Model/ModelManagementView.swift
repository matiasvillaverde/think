import Abstractions
import Database
import SwiftUI

#if os(iOS) || os(visionOS)
    /// A view that manages model selection and discovery in a tabbed interface
    internal struct ModelManagementView: View {
        @Bindable var chat: Chat
        @Binding var isPresented: Bool
        @State private var selectedTab: Tab = .myModels

        enum Tab {
            case myModels
            case discovery
        }

        internal init(chat: Chat, isPresented: Binding<Bool>) {
            self.chat = chat
            _isPresented = isPresented
        }

        internal var body: some View {
            TabView(selection: $selectedTab) {
                myModelsTab

                discoveryTab
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("NavigateToMyModels")
                )
            ) { _ in
                selectedTab = .myModels
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("SwitchToDiscoveryTab")
                )
            ) { _ in
                selectedTab = .discovery
            }
        }

        // MARK: - Private Views

        private var myModelsTab: some View {
            NavigationStack {
                MyModelsView(chat: chat)
                    .navigationTitle("My Models")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                isPresented = false
                            }
                        }
                    }
            }
            .tabItem {
                Label("My Models", systemImage: "tray.full")
            }
            .tag(Tab.myModels)
        }

        private var discoveryTab: some View {
            NavigationStack {
                DiscoveryCarouselView()
                    .navigationTitle("Discover Models")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                isPresented = false
                            }
                        }
                    }
                    .navigationDestination(for: DiscoveredModel.self) { model in
                        DiscoveryModelDetailView(model: model)
                    }
            }
            .tabItem {
                Label("Discover", systemImage: "sparkles")
            }
            .tag(Tab.discovery)
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
