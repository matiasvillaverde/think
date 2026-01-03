import SwiftUI

extension SettingsView {
    var tabsView: some View {
        TabView {
            tabsContent
        }
    }

    @ViewBuilder private var tabsContent: some View {
        actionsTab
        voiceTab
        automationTab
        nodeModeTab
        modelsTab
        pluginsTab
        analyticsTab
        legalTab
        aboutTab
        reviewTab
    }

    private var actionsTab: some View {
        actionsView
            .tabItem {
                actionsTabLabel
            }
    }

    private var voiceTab: some View {
        voiceView
            .tabItem {
                voiceTabLabel
            }
    }

    private var automationTab: some View {
        automationView
            .tabItem {
                automationTabLabel
            }
    }

    private var nodeModeTab: some View {
        nodeModeView
            .tabItem {
                nodeModeTabLabel
            }
    }

    private var modelsTab: some View {
        modelsView
            .tabItem {
                modelsTabLabel
            }
    }

    private var pluginsTab: some View {
        pluginsView
            .tabItem {
                pluginsTabLabel
            }
    }

    private var analyticsTab: some View {
        analyticsView
            .tabItem {
                analyticsTabLabel
            }
    }

    private var legalTab: some View {
        legalView
            .tabItem {
                legalTabLabel
            }
    }

    private var aboutTab: some View {
        AboutView()
            .tabItem {
                aboutTabLabel
            }
    }

    @ViewBuilder private var reviewTab: some View {
        if reviewPromptViewModel.shouldAskForReview, ratingsViewPresented {
            RatingsView(isRatingsViewPresented: ratingsViewPresentedBinding)
                .tabItem {
                    reviewTabLabel
                }
        }
    }
}
