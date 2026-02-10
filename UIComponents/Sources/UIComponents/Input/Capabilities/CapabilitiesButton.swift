import Abstractions
import Database
import SwiftUI

internal struct CapabilitiesButton: View {
    @Environment(\.database)
    private var database: DatabaseProtocol

    @Bindable var chat: Chat
    @Binding var selectedAction: Action

    @State private var showingSheet: Bool = false
    @State private var resolvedPolicy: ResolvedToolPolicy = .allowAll
    @State private var enabledSkillsCount: Int = 0

    private enum Constants {
        static let iconSize: CGFloat = ToolConstants.toolsButtonIconSize
        static let buttonSize: CGFloat = ToolConstants.toolsButtonSize
        static let chipMax: Int = 3
        static let chipSpacing: CGFloat = 6
        static let skillsChipPaddingH: CGFloat = 10
        static let skillsChipPaddingV: CGFloat = 6
        static let skillsChipBackgroundOpacity: Double = 0.7
    }

    var body: some View {
        HStack(spacing: Constants.chipSpacing) {
            capabilitiesButton
            if selectedAction.isTextual {
                capabilitiesChips
            }
        }
        .task(id: chat.id) {
            await refresh()
        }
    }

    private var capabilitiesButton: some View {
        Button {
            showingSheet = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: Constants.iconSize, weight: .medium))
                .foregroundColor(Color.textPrimary)
                .accessibilityLabel(String(
                    localized: "Capabilities",
                    bundle: .module,
                    comment: "Button to show capabilities"
                ))
        }
        .buttonStyle(.plain)
        .frame(width: Constants.buttonSize, height: Constants.buttonSize)
        #if os(macOS)
            .popover(isPresented: $showingSheet) {
                CapabilitiesSheet(chat: chat, selectedAction: $selectedAction) {
                    showingSheet = false
                }
                .frame(
                    minWidth: ToolConstants.popoverMinWidth,
                    minHeight: ToolConstants.popoverMinHeight
                )
                .presentationCompactAdaptation(.popover)
            }
        #else
            .sheet(isPresented: $showingSheet) {
                CapabilitiesSheet(chat: chat, selectedAction: $selectedAction) {
                    showingSheet = false
                }
            }
        #endif
    }

    @ViewBuilder private var capabilitiesChips: some View {
        let supported: Set<ToolIdentifier> = CapabilitiesToolSupport.supportedTextTools()
        let tools: [ToolIdentifier] =
            Array(resolvedPolicy.allowedTools.intersection(supported))
                .sorted { $0.rawValue < $1.rawValue }
        let visibleTools: [ToolIdentifier] = Array(tools.prefix(Constants.chipMax))

        if !tools.isEmpty {
            ForEach(visibleTools, id: \.self) { tool in
                ToolChip(tool: tool) {
                    removeToolFromPersonalityPolicy(tool)
                }
            }

            if tools.count > Constants.chipMax {
                Text(verbatim: "+\(tools.count - Constants.chipMax)")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }

        if enabledSkillsCount > 0 {
            Text(String(
                localized: "Skills: \(enabledSkillsCount)",
                bundle: .module,
                comment: "Chip indicating how many skills are enabled"
            ))
            .font(.caption)
            .padding(.horizontal, Constants.skillsChipPaddingH)
            .padding(.vertical, Constants.skillsChipPaddingV)
            .background(Color.backgroundSecondary.opacity(Constants.skillsChipBackgroundOpacity))
            .clipShape(Capsule())
        }
    }

    private func refresh() async {
        do {
            let policy: ResolvedToolPolicy = try await database.read(
                ToolPolicyCommands.ResolveForChat(chatId: chat.id)
            )
            resolvedPolicy = policy

            let supported: Set<ToolIdentifier> = CapabilitiesToolSupport.supportedTextTools()
            let toolNames: Set<String> =
                Set(policy.allowedTools.intersection(supported).map(\.toolName))
            let skills: [Skill] = try await database.read(
                SkillCommands.GetForTools(toolIdentifiers: toolNames, chatId: chat.id)
            )
            enabledSkillsCount = skills.count

            // For text mode, default the requested tool set to the effective policy.
            if selectedAction.isTextual {
                await MainActor.run {
                    selectedAction = .textGeneration(policy.allowedTools.intersection(supported))
                }
            }
        } catch {
            resolvedPolicy = .allowAll
            enabledSkillsCount = 0
        }
    }

    private func removeToolFromPersonalityPolicy(_ tool: ToolIdentifier) {
        Task {
            // Translate "remove chip" as "deny tool" for the personality policy.
            guard let personalityPolicy = try? await database.read(
                ToolPolicyCommands.GetForPersonality(personalityId: chat.personality.id)
            ) else {
                _ = try? await database.write(
                    ToolPolicyCommands.UpsertForPersonality(
                        personalityId: chat.personality.id,
                        profile: .full,
                        allowList: [],
                        denyList: [tool.toolName]
                    )
                )
                await refresh()
                return
            }

            var deny: Set<String> = Set(personalityPolicy.denyList)
            deny.insert(tool.toolName)

            _ = try? await database.write(
                ToolPolicyCommands.UpsertForPersonality(
                    personalityId: chat.personality.id,
                    profile: personalityPolicy.profile,
                    allowList: personalityPolicy.allowList,
                    denyList: Array(deny).sorted()
                )
            )
            await refresh()
        }
    }
}
