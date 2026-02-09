import SwiftUI

// swiftlint:disable closure_body_length
// swiftlint:disable line_length
// swiftlint:disable type_body_length

// **MARK: - Privacy Policy View**
public struct PrivacyPolicyView: View {
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
                    localized: "Privacy Policy for Think AI",
                    bundle: .module,
                    comment: "Title for Privacy Policy screen"
                ))
                .font(.title)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

                Divider()

                Text(String(
                    localized: "Effective Date: April 10, 2025",
                    bundle: .module,
                    comment: "Last updated date for Privacy Policy"
                ))
                .font(.caption)
                .foregroundColor(Color.textSecondary)

                privacyContent
            }
            .padding(Constants.contentPadding)
        }
    }

    // **MARK: - Privacy Content**
    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            // Introduction
            Group {
                Text(String(
                    localized: "Introduction",
                    bundle: .module,
                    comment: "Privacy Policy section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "Welcome to Think AI. This Privacy Policy outlines how your information is handled when using our application. We have designed Think AI with privacy as a fundamental principle, operating with complete offline functionality to ensure maximum data protection.",
                    bundle: .module,
                    comment: "Privacy Policy introduction content"
                ))
            }

            // 1. Data Collection and Usage
            Group {
                Text(String(
                    localized: "1. Data Collection and Usage",
                    bundle: .module,
                    comment: "Privacy Policy section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "1.1 No Data Collection Policy",
                    bundle: .module,
                    comment: "Privacy Policy subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "Think AI does not collect, store, transmit, or process any of the following: user input text or prompts, generated AI content, usage patterns or analytics, personal identifiable information, or device information.",
                    bundle: .module,
                    comment: "Privacy Policy section content"
                ))

                Text(String(
                    localized: "1.2 Local Processing Only",
                    bundle: .module,
                    comment: "Privacy Policy subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "All AI operations occur entirely on your local device. The application operates offline without requiring internet connectivity, does not transmit data to external servers, does not maintain databases of user interactions, and does not log your conversations or creations.",
                    bundle: .module,
                    comment: "Privacy Policy section content"
                ))

                Text(String(
                    localized: "1.3 Diagnostic Information",
                    bundle: .module,
                    comment: "Privacy Policy subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "The only circumstance where any information might be shared with us is when you explicitly choose to report a bug and voluntarily attach diagnostic logs to your email. These logs are automatically obfuscated to remove any personal or sensitive information before being attached.",
                    bundle: .module,
                    comment: "Privacy Policy section content"
                ))
            }

            // 2. Third-Party AI Models
            Group {
                Text(String(
                    localized: "2. Third-Party AI Models",
                    bundle: .module,
                    comment: "Privacy Policy section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "2.1 Model Selection and Responsibility",
                    bundle: .module,
                    comment: "Privacy Policy subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "Think AI now supports multiple open-source AI models. Please note: We do not create, train, or modify these models; we provide access to these models for local use only; we are not responsible for the content generated by these models; you are responsible for researching and understanding the capabilities, limitations, and potential biases of any model you choose to use.",
                    bundle: .module,
                    comment: "Privacy Policy section content"
                ))

                Text(String(
                    localized: "2.2 Model Disclaimers",
                    bundle: .module,
                    comment: "Privacy Policy subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "When using any AI model within Think AI: Content generated may contain inaccuracies, biases, or inappropriate material; models may produce outputs reflecting biases in their training data; models' knowledge is limited to their training cutoff dates; performance may vary between different language inputs; you assume full responsibility for verifying any generated content.",
                    bundle: .module,
                    comment: "Privacy Policy section content"
                ))
            }

            // 3. User Responsibilities
            Group {
                Text(String(
                    localized: "3. User Responsibilities",
                    bundle: .module,
                    comment: "Privacy Policy section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "3.1 Content Verification",
                    bundle: .module,
                    comment: "Privacy Policy subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "You acknowledge and agree that: You are solely responsible for reviewing and verifying any AI-generated content; the application makes no warranty as to the accuracy, appropriateness, or legality of generated content; you will not use the application for generating content in high-risk domains (medical, legal, financial advice) without appropriate professional oversight.",
                    bundle: .module,
                    comment: "Privacy Policy section content"
                ))

                Text(String(
                    localized: "3.2 Compliance with Laws",
                    bundle: .module,
                    comment: "Privacy Policy subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "You are responsible for: Ensuring your use of the application complies with all applicable laws and regulations; obtaining any necessary rights or permissions for content you input; using generated content in accordance with relevant copyright and intellectual property laws.",
                    bundle: .module,
                    comment: "Privacy Policy section content"
                ))
            }

            // 4. Liability Limitations
            Group {
                Text(String(
                    localized: "4. Liability Limitations",
                    bundle: .module,
                    comment: "Privacy Policy section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "4.1 Developer's Limited Liability",
                    bundle: .module,
                    comment: "Privacy Policy subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "To the maximum extent permitted by law: The application is provided \"AS IS\" without warranties of any kind; Matias Villaverde disclaims all liability for any consequences arising from the use of the application; this includes any direct, indirect, incidental, special, consequential, or exemplary damages; the developer does not endorse, verify, or assume responsibility for any content generated through the application.",
                    bundle: .module,
                    comment: "Privacy Policy section content"
                ))

                Text(String(
                    localized: "4.2 Model Provider Liability",
                    bundle: .module,
                    comment: "Privacy Policy subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "Think AI serves solely as an interface to access third-party AI models locally: All responsibility for model outputs rests with the respective model providers and ultimately with you as the end user; the developer makes no representations regarding the quality, capabilities, or limitations of any included models; you acknowledge that research into any model's capabilities and limitations is your responsibility.",
                    bundle: .module,
                    comment: "Privacy Policy section content"
                ))
            }

            // 5. Data Security
            Group {
                Text(String(
                    localized: "5. Data Security",
                    bundle: .module,
                    comment: "Privacy Policy section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "5.1 Local Storage Security",
                    bundle: .module,
                    comment: "Privacy Policy subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "While we do not collect your data: All application operations occur locally on your device; data security is dependent on your device's security measures; we recommend maintaining updated device security to protect any locally stored information.",
                    bundle: .module,
                    comment: "Privacy Policy section content"
                ))

                Text(String(
                    localized: "5.2 Communications",
                    bundle: .module,
                    comment: "Privacy Policy subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "In the rare instance you communicate with us: Bug reports and associated logs are transmitted via your email service; no automated data transmission occurs without your explicit action; diagnostic logs are automatically obfuscated to protect your privacy.",
                    bundle: .module,
                    comment: "Privacy Policy section content"
                ))
            }

            // 6. Changes to Privacy Policy
            Group {
                Text(String(
                    localized: "6. Changes to Privacy Policy",
                    bundle: .module,
                    comment: "Privacy Policy section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "We reserve the right to update this Privacy Policy at any time. Changes will be effective immediately upon posting within the application or on our website. Continued use constitutes acceptance of any modifications.",
                    bundle: .module,
                    comment: "Privacy Policy section content"
                ))
            }

            // 7. Legal Disclaimer
            Group {
                Text(String(
                    localized: "7. Legal Disclaimer",
                    bundle: .module,
                    comment: "Privacy Policy section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "7.1 No Legal Recourse",
                    bundle: .module,
                    comment: "Privacy Policy subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "You agree that to the fullest extent permitted by law: You will not pursue legal action against the developer for claims related to content generated by any AI model; you acknowledge the inherent limitations and unpredictability of AI-generated content; you use the application understanding these limitations.",
                    bundle: .module,
                    comment: "Privacy Policy section content"
                ))

                Text(String(
                    localized: "7.2 Prohibited Uses",
                    bundle: .module,
                    comment: "Privacy Policy subsection title"
                ))
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(String(
                    localized: "The application may not be used for: Generating content that violates applicable laws; creating discriminatory, harassing, or harmful material; developing content intended to deceive or defraud; any purpose that could reasonably be expected to cause harm.",
                    bundle: .module,
                    comment: "Privacy Policy section content"
                ))
            }

            // 8. Contact Information
            Group {
                Text(String(
                    localized: "8. Contact Information",
                    bundle: .module,
                    comment: "Privacy Policy section title"
                ))
                .font(.headline)
                .padding(.top)

                Text(String(
                    localized: "For questions or concerns about this Privacy Policy, please contact: contact.app",
                    bundle: .module,
                    comment: "Privacy Policy section content"
                ))

                Text(String(
                    localized: "By using Think AI, you acknowledge that you have read, understood, and agree to be bound by this Privacy Policy. If you do not agree with these terms, please discontinue use immediately.",
                    bundle: .module,
                    comment: "Privacy Policy agreement text"
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
}

#Preview {
    PrivacyPolicyView()
}
