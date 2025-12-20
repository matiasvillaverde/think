import SwiftUI

// MARK: - Disclaimer View

internal struct DisclaimerView: View {
    private enum Constants {
        static let paddingTop: CGFloat = 200
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.standard) {
            Text(String(localized: "DISCLAIMER AND LIMITATION OF LIABILITY", bundle: .module))
                .font(.footnote)
                .bold()
                .foregroundColor(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignConstants.Spacing.standard)
                .padding(.top, DesignConstants.Spacing.standard)
            footer
        }.padding(.top, Constants.paddingTop)
    }

    private var footer: some View {
        // swiftlint:disable line_length
        let text: String = String(localized: """
        Think AI hereby expressly disclaims any and all ownership, control, involvement in creation, or responsibility for any and all AI models ("Models") available through this application. All Models are created, developed, and provided exclusively by third parties and are made available via Hugging Face or other repositories, each subject to their own respective licenses, terms, and conditions.

        Think AI makes no representations or warranties of any kind, whether express, implied, statutory, or otherwise, regarding the Models, including, without limitation, any warranty that the Models will be error-free, accurate, reliable, of merchantable quality, fit for a particular purpose, non-infringing, or otherwise meet your requirements or expectations.

        BY ACCESSING, DOWNLOADING, OR USING ANY MODEL THROUGH THIS APPLICATION, YOU ACKNOWLEDGE AND AGREE THAT:

        1. Think AI exercises no editorial control over any Model content, capabilities, or outputs;

        2. Models may generate content that may be offensive, harmful, biased, inaccurate, misleading, defamatory, illegal, or otherwise objectionable;

        3. You assume full and exclusive responsibility and liability for all decisions, actions, and consequences stemming from your use of any Model;

        4. Think AI shall not, under any circumstances or legal theory, be liable for any direct, indirect, incidental, special, consequential, punitive, exemplary, or other damages arising out of or relating to your use of or inability to use any Model, even if Think AI has been advised of the possibility of such damages;

        5. You shall indemnify, defend, and hold harmless Think AI, its officers, directors, employees, agents, successors, and assigns from and against any and all claims, damages, liabilities, costs, and expenses (including reasonable attorneys' fees) arising from or relating to your use of any Model.

        This disclaimer constitutes an essential part of the agreement between you and Think AI. If any provision of this disclaimer is found to be unenforceable or invalid, the remaining provisions shall remain in full force and effect to the maximum extent permitted by applicable law.
        """, bundle: .module)
        // swiftlint:enable line_length

        return Text(text)
            .font(.footnote)
            .foregroundColor(Color.textSecondary)
            .padding(DesignConstants.Spacing.standard)
    }
}
