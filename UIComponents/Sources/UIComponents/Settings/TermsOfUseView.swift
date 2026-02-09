import SwiftUI

// swiftlint:disable closure_body_length
// swiftlint:disable line_length
// swiftlint:disable type_body_length

// **MARK: - Terms of Use View**
public struct TermsOfUseView: View {
    // **MARK: - Constants**
    private enum Constants {
        static let contentPadding: CGFloat = 16
        static let titleSpacing: CGFloat = 8
        static let lineSpacing: CGFloat = 4
        static let sectionSpacing: CGFloat = 12
    }

    // **MARK: - Initializer**
    public init() {
        // Default initializer
    }

    // **MARK: - Body**
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.titleSpacing) {
                Text(String(
                    localized: "Terms and Conditions for Think AI",
                    bundle: .module,
                    comment: "Title for Terms of Use screen"
                ))
                .font(.title)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

                Divider()

                Text(String(
                    localized: "Effective Date: April 10, 2025",
                    bundle: .module,
                    comment: "Last updated date for Terms of Use"
                ))
                .font(.caption)
                .foregroundColor(Color.textSecondary)

                Text(String(
                    localized: "Thank you for using Think AI!",
                    bundle: .module,
                    comment: "Welcome message"
                ))
                .padding(.top)
                .fontWeight(.medium)

                termsContent
            }
            .padding(Constants.contentPadding)
        }
    }

    // **MARK: - Terms Content**
    private var termsContent: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            // Introduction
            Group {
                Text(String(
                    localized: "Introduction",
                    bundle: .module,
                    comment: "Terms of Use section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "These Terms and Conditions constitute a legally binding agreement between you and Matias Villaverde, the developer of Think AI, regarding your use of the Think AI application. By downloading, installing, or using the App, you acknowledge that you have read, understood, and agree to be bound by these Terms.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))
            }

            // Who We Are
            Group {
                Text(String(
                    localized: "Who We Are",
                    bundle: .module,
                    comment: "Terms of Use section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "Think AI is a locally-run artificial intelligence application that enables users to access and utilize open-source AI models directly on their personal devices. Our mission is to provide accessible AI tools while maintaining the highest standards of privacy and user control.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))
            }

            // Key Features
            Group {
                Text(String(
                    localized: "Key Features and Differences",
                    bundle: .module,
                    comment: "Terms of Use section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "Unlike cloud-based AI services, Think AI: operates entirely offline on your local device; does not collect, store, or transmit your inputs or outputs; allows you to download and use various open-source AI models; and processes all data locally without requiring internet connectivity for core functionality.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))
            }

            // Registration and Access
            Group {
                Text(String(
                    localized: "1. Registration and Access",
                    bundle: .module,
                    comment: "Terms of Use section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "Minimum Age",
                    bundle: .module,
                    comment: "Terms of Use subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "You must be at least 13 years old or the minimum age required in your country to consent to use the App. If you are under 18, you must have your parent or legal guardian's permission to use the App.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))

                Text(String(
                    localized: "Installation and Account",
                    bundle: .module,
                    comment: "Terms of Use subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "The App may be installed directly on your device. If the App requires account creation, you must provide accurate and complete information. You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))
            }

            // Using the App
            Group {
                Text(String(
                    localized: "2. Using the App",
                    bundle: .module,
                    comment: "Terms of Use section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "What You Can Do",
                    bundle: .module,
                    comment: "Terms of Use subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "Subject to your compliance with these Terms, you may: install and use the App on your personal devices; download and utilize available open-source AI models within the App; generate content for personal use in accordance with applicable laws; and share content you generate, provided you comply with applicable laws.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))

                Text(String(
                    localized: "What You Cannot Do",
                    bundle: .module,
                    comment: "Terms of Use subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "You may not use the App for any illegal, harmful, or abusive activity. Specifically, you may not: use the App to infringe upon anyone's rights; modify, decompile, or reverse engineer the App; redistribute, lease, or sell the App; represent that output was human-generated when it was not; use the App to develop competing AI applications; use the App to generate illegal content; or use outputs to harm, harass, or deceive others.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))

                Text(String(
                    localized: "Open-Source Models",
                    bundle: .module,
                    comment: "Terms of Use subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "The App allows you to download and use various open-source AI models. The Developer does not create, train, or modify these models and only provides access for local use. You are responsible for researching and understanding the capabilities, limitations, and potential biases of any model you choose to use.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))
            }

            // Content and Ownership
            Group {
                Text(String(
                    localized: "3. Content and Ownership",
                    bundle: .module,
                    comment: "Terms of Use section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "Your Content",
                    bundle: .module,
                    comment: "Terms of Use subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "You may provide input to the App and receive output based on that input. You are solely responsible for all Content, including ensuring that it does not violate any applicable law or these Terms.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))

                Text(String(
                    localized: "Ownership of Content",
                    bundle: .module,
                    comment: "Terms of Use subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "As between you and the Developer: you retain all ownership rights in your input, you own the output generated by the App through your use, and the Developer makes no claim to any rights in your Content.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))

                Text(String(
                    localized: "Local Processing Only",
                    bundle: .module,
                    comment: "Terms of Use subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "All Content is processed entirely on your local device. The App does not transmit your Content to external servers, does not store your Content in any cloud database, does not maintain logs of your interactions, and does not use your Content to train or improve models.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))

                Text(String(
                    localized: "Content Accuracy",
                    bundle: .module,
                    comment: "Terms of Use subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "AI and machine learning are rapidly evolving fields. The App's output may not always be accurate, complete, or appropriate. You should not rely on output as a sole source of truth or factual information, and you must evaluate all output for accuracy and appropriateness before using or sharing it.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))
            }

            // Disclaimers and Limitations
            Group {
                Text(String(
                    localized: "4. Disclaimers and Limitations of Liability",
                    bundle: .module,
                    comment: "Terms of Use section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "Disclaimer of Warranties",
                    bundle: .module,
                    comment: "Terms of Use subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "THE APP IS PROVIDED \"AS IS\" AND \"AS AVAILABLE\" WITHOUT WARRANTIES OF ANY KIND. TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE DEVELOPER EXPRESSLY DISCLAIMS ALL WARRANTIES, INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, ERROR-FREE OPERATION, AND ACCURACY OF OUTPUT.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))

                Text(String(
                    localized: "Limitation of Liability",
                    bundle: .module,
                    comment: "Terms of Use subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "TO THE MAXIMUM EXTENT PERMITTED BY LAW, THE DEVELOPER SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR EXEMPLARY DAMAGES, INCLUDING DAMAGES FOR LOSS OF PROFITS, GOODWILL, USE, OR DATA ARISING OUT OF OR RELATED TO YOUR USE OF THE APP. IN NO EVENT SHALL THE DEVELOPER'S TOTAL LIABILITY EXCEED THE AMOUNT YOU PAID FOR THE APP, IF ANY.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))
            }

            // User Responsibility
            Group {
                Text(String(
                    localized: "5. User Responsibility and Indemnification",
                    bundle: .module,
                    comment: "Terms of Use section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "User Responsibility",
                    bundle: .module,
                    comment: "Terms of Use subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "You are solely responsible for: your use of the App and any Content it generates; complying with all applicable laws and regulations; determining the appropriateness of using the App for any purpose; evaluating and verifying all Content generated by the App; and securing your device and protecting your data.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))

                Text(String(
                    localized: "Indemnification",
                    bundle: .module,
                    comment: "Terms of Use subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "To the fullest extent permitted by law, you agree to indemnify, defend, and hold harmless the Developer from any claims, liabilities, damages, judgments, losses, costs, or fees arising out of your violation of these Terms, your use of the App, your violation of any third-party right, or any claim that your use of the App caused damage to a third party.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))
            }

            // Termination
            Group {
                Text(String(
                    localized: "6. Termination",
                    bundle: .module,
                    comment: "Terms of Use section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "You may terminate your use of the App at any time by uninstalling it from your device(s). The Developer reserves the right to terminate or suspend your access to the App at any time, without prior notice or liability, if you breach these Terms.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))
            }

            // Dispute Resolution
            Group {
                Text(String(
                    localized: "7. Dispute Resolution",
                    bundle: .module,
                    comment: "Terms of Use section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "These Terms shall be governed by and construed in accordance with the laws of Argentina, without regard to its conflict of law principles. Any dispute arising out of or relating to these Terms or the App shall be resolved exclusively in the courts of Buenos Aires, Argentina.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))

                Text(String(
                    localized: "YOU WAIVE ANY RIGHT TO PARTICIPATE AS A PLAINTIFF OR CLASS MEMBER IN ANY PURPORTED CLASS ACTION LAWSUIT, CLASS-WIDE ARBITRATION, OR ANY OTHER REPRESENTATIVE PROCEEDING RELATING TO THE APP OR THESE TERMS.",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))
            }

            // Contact Info
            Group {
                Text(String(
                    localized: "Contact Information",
                    bundle: .module,
                    comment: "Terms of Use section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "For questions about these Terms, please contact: contact.app",
                    bundle: .module,
                    comment: "Terms of Use section content"
                ))

                Text(String(
                    localized: "By using Think AI, you acknowledge that you have read, understood, and agree to be bound by these Terms of Use. If you do not agree to these Terms, you must not use the App.",
                    bundle: .module,
                    comment: "Terms agreement statement"
                ))
                .padding(.top, Constants.titleSpacing)
                .fontWeight(.medium)
            }
        }
        .lineSpacing(Constants.lineSpacing)
    }
    // swiftlint:enable closure_body_length
    // swiftlint:enable line_length
    // swiftlint:enable type_body_length
    // swiftlint:disable file_length
}

// **MARK: - Preview**
#if DEBUG
    #Preview {
        TermsOfUseView()
    }
#endif

// swiftlint:enable file_length
