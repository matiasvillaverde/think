import Database
import SwiftUI

internal struct CapabilitiesSkillsSection: View {
    let skills: [Skill]
    let onSetEnabled: (Skill, Bool) -> Void

    internal var body: some View {
        VStack(alignment: .leading, spacing: CapabilitiesSheet.Constants.sectionSpacing) {
            Text(String(localized: "Skills", bundle: .module))
                .font(.subheadline.weight(.semibold))

            if skills.isEmpty {
                Text(String(
                    localized: "No skills configured yet.",
                    bundle: .module,
                    comment: "Empty state when no skills exist"
                ))
                .font(.caption)
                .foregroundColor(.textSecondary)
            } else {
                ForEach(skills, id: \.id) { skill in
                    Toggle(
                        skill.name,
                        isOn: Binding(
                            get: { skill.isEnabled },
                            set: { newValue in onSetEnabled(skill, newValue) }
                        )
                    )
                }
            }
        }
    }
}
