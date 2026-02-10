import Abstractions
import Database
import SwiftUI

internal struct CapabilitiesSheet: View {
    @Environment(\.database)
    private var database: DatabaseProtocol

    let chat: Chat
    @Binding var selectedAction: Action
    let onDismiss: () -> Void

    @State private var resolvedPolicy: ResolvedToolPolicy = .allowAll
    @State private var personalityPolicy: ToolPolicy?

    @State private var draftProfile: ToolProfile = .full
    @State private var draftAllowList: Set<ToolIdentifier> = []
    @State private var draftDenyList: Set<ToolIdentifier> = []

    @State private var skills: [Skill] = []
    @State private var isLoading: Bool = false

    internal enum Constants {
        static let sheetSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 8
    }

    internal var body: some View {
        platformSpecificView()
            .task(id: chat.id) {
                await refresh()
            }
    }

    @ViewBuilder
    private func platformSpecificView() -> some View {
        #if os(iOS) || os(visionOS)
            NavigationView {
                content
                    .navigationTitle(String(
                        localized: "Capabilities",
                        bundle: .module,
                        comment: "Navigation title for capabilities sheet"
                    ))
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Done", bundle: .module)) {
                                onDismiss()
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        #else
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(String(localized: "Capabilities", bundle: .module))
                        .font(.headline)
                    Spacer()
                    Button(String(localized: "Done", bundle: .module)) {
                        onDismiss()
                    }
                }
                .padding(.horizontal, ToolConstants.sheetSpacing)
                .padding(.vertical, ToolConstants.popoverTitleVerticalPadding)

                Divider()

                content
            }
        #endif
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.sheetSpacing) {
                if isLoading {
                    ProgressView()
                        .padding(.top, Constants.sheetSpacing)
                }

                CapabilitiesToolProfileSection(draftProfile: $draftProfile) {
                    // Switching profile resets customizations for clarity.
                    draftAllowList = []
                    draftDenyList = []
                    persistDraftPolicy()
                }

                CapabilitiesToolsSection(
                    chat: chat,
                    toolOrder: toolOrder,
                    effectiveTools: effectiveTools
                ) { tool, isOn in
                    handleToolToggle(tool: tool, isOn: isOn)
                }

                CapabilitiesSkillsSection(skills: skills) { skill, isEnabled in
                    setSkillEnabled(skill, isEnabled: isEnabled)
                }

                CapabilitiesDiagnosticsSection(resolvedPolicy: resolvedPolicy)

                Spacer(minLength: Constants.sheetSpacing)
            }
            .padding(.horizontal, ToolConstants.sheetSpacing)
            .padding(.top, ToolConstants.sheetSpacing)
        }
    }

    private var effectiveTools: Set<ToolIdentifier> {
        let base: Set<ToolIdentifier> = draftProfile.includedTools
        let requested: Set<ToolIdentifier> = base
            .union(draftAllowList)
            .subtracting(draftDenyList)
            // Image generation is a distinct action, not a text tool-call capability.
            .subtracting([.imageGeneration])
        return requested.intersection(CapabilitiesToolSupport.supportedTextTools())
    }

    private var toolOrder: [ToolIdentifier] {
        var tools: [ToolIdentifier] = [
            .browser,
            .duckduckgo,
            .braveSearch,
            .weather,
            .python,
            .functions,
            .memory
        ]

        #if os(iOS)
            tools.append(.healthKit)
        #endif

        return tools
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        await refreshPolicy()
        await refreshSkillsOnly()
        await syncSelectedActionFromEffectiveTools()
    }

    private func refreshPolicy() async {
        do {
            resolvedPolicy = try await database.read(
                ToolPolicyCommands.ResolveForChat(chatId: chat.id)
            )
            personalityPolicy = try await database.read(
                ToolPolicyCommands.GetForPersonality(personalityId: chat.personality.id)
            )
        } catch {
            resolvedPolicy = .allowAll
            personalityPolicy = nil
        }

        if let personalityPolicy {
            draftProfile = personalityPolicy.profile
            draftAllowList = Set(
                personalityPolicy.allowList.compactMap(ToolIdentifier.from(toolName:))
            )
            draftDenyList = Set(
                personalityPolicy.denyList.compactMap(ToolIdentifier.from(toolName:))
            )
        } else {
            draftProfile = resolvedPolicy.sourceProfile
            draftAllowList = []
            draftDenyList = []
        }

        draftAllowList.remove(.imageGeneration)
        draftDenyList.remove(.imageGeneration)
    }

    private func refreshSkillsOnly() async {
        do {
            skills = try await database.read(SkillCommands.GetAll())
        } catch {
            skills = []
        }
    }

    private func syncSelectedActionFromEffectiveTools() async {
        guard selectedAction.isTextual else {
            return
        }
        await MainActor.run {
            selectedAction = .textGeneration(effectiveTools)
        }
    }

    private func persistDraftPolicy() {
        Task {
            _ = try? await database.write(
                ToolPolicyCommands.UpsertForPersonality(
                    personalityId: chat.personality.id,
                    profile: draftProfile,
                    allowList: draftAllowList.map(\.toolName).sorted(),
                    denyList: draftDenyList.map(\.toolName).sorted()
                )
            )
            await refreshPolicy()
            await syncSelectedActionFromEffectiveTools()
        }
    }

    private func handleToolToggle(tool: ToolIdentifier, isOn: Bool) {
        let profileBase: Set<ToolIdentifier> = draftProfile.includedTools

        if isOn {
            draftDenyList.remove(tool)
            if !profileBase.contains(tool) {
                draftAllowList.insert(tool)
            }
        } else {
            draftAllowList.remove(tool)
            if profileBase.contains(tool) {
                draftDenyList.insert(tool)
            }
        }

        persistDraftPolicy()
    }

    private func setSkillEnabled(_ skill: Skill, isEnabled: Bool) {
        Task {
            _ = try? await database.write(
                SkillCommands.SetEnabled(
                    skillId: skill.id,
                    isEnabled: isEnabled
                )
            )
            await refreshSkillsOnly()
        }
    }
}
