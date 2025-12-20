import Foundation

/// Maps license identifiers to their official documentation URLs
///
/// This utility provides URL mappings for common open-source licenses,
/// Creative Commons licenses, and AI-specific model licenses.
///
/// ## Example Usage
/// ```swift
/// let url = LicenseMapper.urlForLicense("apache-2.0")
/// // Returns: "https://www.apache.org/licenses/LICENSE-2.0"
///
/// let unknownUrl = LicenseMapper.urlForLicense("custom-license")
/// // Returns: nil
/// ```
enum LicenseMapper {
    /// Maps license identifiers to their official URLs
    private static let licenseUrls: [String: String] = [
        // Common Open Source Licenses
        "apache-2.0": "https://www.apache.org/licenses/LICENSE-2.0",
        "mit": "https://opensource.org/licenses/MIT",
        "gpl-3.0": "https://www.gnu.org/licenses/gpl-3.0.html",
        "gpl-2.0": "https://www.gnu.org/licenses/gpl-2.0.html",
        "lgpl-3.0": "https://www.gnu.org/licenses/lgpl-3.0.html",
        "lgpl-2.1": "https://www.gnu.org/licenses/lgpl-2.1.html",
        "bsd-3-clause": "https://opensource.org/licenses/BSD-3-Clause",
        "bsd-2-clause": "https://opensource.org/licenses/BSD-2-Clause",
        "mpl-2.0": "https://www.mozilla.org/en-US/MPL/2.0/",
        "isc": "https://opensource.org/licenses/ISC",
        "unlicense": "https://unlicense.org/",
        "wtfpl": "https://www.wtfpl.net/about/",
        "artistic-2.0": "https://opensource.org/licenses/Artistic-2.0",
        "epl-2.0": "https://www.eclipse.org/legal/epl-2.0/",
        "epl-1.0": "https://www.eclipse.org/legal/epl-v10.html",
        "zlib": "https://opensource.org/licenses/Zlib",

        // Creative Commons Licenses
        "cc-by-4.0": "https://creativecommons.org/licenses/by/4.0/",
        "cc-by-sa-4.0": "https://creativecommons.org/licenses/by-sa/4.0/",
        "cc-by-nc-4.0": "https://creativecommons.org/licenses/by-nc/4.0/",
        "cc-by-nc-sa-4.0": "https://creativecommons.org/licenses/by-nc-sa/4.0/",
        "cc0-1.0": "https://creativecommons.org/publicdomain/zero/1.0/",

        // AI Model Specific Licenses
        // Meta LLaMA licenses
        "llama2": "https://ai.meta.com/llama/license/",
        "llama3": "https://llama.meta.com/llama3/license/",
        "llama3.1": "https://llama.meta.com/llama3_1/license/",
        "llama3.2": "https://llama.meta.com/llama3_2/license/",
        "llama3.3": "https://llama.meta.com/llama3_3/license/",

        // Google Gemma
        "gemma": "https://ai.google.dev/gemma/terms",

        // DeepSeek
        "deepseek": "https://github.com/deepseek-ai/DeepSeek-V2/blob/main/LICENSE-MODEL",
        "deepseek-license": "https://github.com/deepseek-ai/DeepSeek-V2/blob/main/LICENSE-MODEL",

        // OpenRAIL licenses
        "openrail": "https://www.licenses.ai/ai-pubs-open-rails-vz1",
        "openrail-m": "https://www.licenses.ai/ai-model-openrail-m-vz1",
        "openrail++": "https://www.licenses.ai/ai-pubs-open-rails-vz1",
        "creativeml-openrail-m": "https://huggingface.co/spaces/CompVis/stable-diffusion-license",

        // BigScience
        "bigscience-bloom-rail-1.0": "https://bigscience.huggingface.co/blog/the-bigscience-rail-license",

        // Stability AI
        "stability-ai-community": "https://huggingface.co/stabilityai/stable-diffusion-2/blob/main/LICENSE-MODEL"
    ]

    /// Returns the URL for a given license identifier
    /// - Parameter identifier: The license identifier (e.g., "apache-2.0", "MIT")
    /// - Returns: The URL to the license documentation, or nil if not found
    static func urlForLicense(_ identifier: String?) -> String? {
        guard let identifier else { return nil }

        // Trim whitespace and normalize to lowercase
        let normalizedIdentifier: String = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Return nil for empty strings
        guard !normalizedIdentifier.isEmpty else { return nil }

        // Look up the license URL
        return licenseUrls[normalizedIdentifier]
    }
}
