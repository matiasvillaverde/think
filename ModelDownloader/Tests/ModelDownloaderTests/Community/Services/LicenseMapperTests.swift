import Foundation
@testable import ModelDownloader
import Testing

@Suite("LicenseMapper Tests")
struct LicenseMapperTests {
    @Test("Maps common open source licenses to URLs")
    func testCommonLicenses() {
        // Apache License 2.0
        #expect(LicenseMapper.urlForLicense("apache-2.0") == "https://www.apache.org/licenses/LICENSE-2.0")
        #expect(LicenseMapper.urlForLicense("Apache-2.0") == "https://www.apache.org/licenses/LICENSE-2.0")
        #expect(LicenseMapper.urlForLicense("APACHE-2.0") == "https://www.apache.org/licenses/LICENSE-2.0")

        // MIT License
        #expect(LicenseMapper.urlForLicense("mit") == "https://opensource.org/licenses/MIT")
        #expect(LicenseMapper.urlForLicense("MIT") == "https://opensource.org/licenses/MIT")

        // GPL Licenses
        #expect(LicenseMapper.urlForLicense("gpl-3.0") == "https://www.gnu.org/licenses/gpl-3.0.html")
        #expect(LicenseMapper.urlForLicense("GPL-3.0") == "https://www.gnu.org/licenses/gpl-3.0.html")
        #expect(LicenseMapper.urlForLicense("gpl-2.0") == "https://www.gnu.org/licenses/gpl-2.0.html")

        // LGPL Licenses
        #expect(LicenseMapper.urlForLicense("lgpl-3.0") == "https://www.gnu.org/licenses/lgpl-3.0.html")
        #expect(LicenseMapper.urlForLicense("lgpl-2.1") == "https://www.gnu.org/licenses/lgpl-2.1.html")

        // BSD Licenses
        #expect(LicenseMapper.urlForLicense("bsd-3-clause") == "https://opensource.org/licenses/BSD-3-Clause")
        #expect(LicenseMapper.urlForLicense("bsd-2-clause") == "https://opensource.org/licenses/BSD-2-Clause")

        // Mozilla Public License
        #expect(LicenseMapper.urlForLicense("mpl-2.0") == "https://www.mozilla.org/en-US/MPL/2.0/")

        // ISC License
        #expect(LicenseMapper.urlForLicense("isc") == "https://opensource.org/licenses/ISC")
    }

    @Test("Maps Creative Commons licenses")
    func testCreativeCommonsLicenses() {
        #expect(LicenseMapper.urlForLicense("cc-by-4.0") == "https://creativecommons.org/licenses/by/4.0/")
        #expect(LicenseMapper.urlForLicense("cc-by-sa-4.0") == "https://creativecommons.org/licenses/by-sa/4.0/")
        #expect(LicenseMapper.urlForLicense("cc-by-nc-4.0") == "https://creativecommons.org/licenses/by-nc/4.0/")
        #expect(LicenseMapper.urlForLicense("cc-by-nc-sa-4.0") == "https://creativecommons.org/licenses/by-nc-sa/4.0/")
        #expect(LicenseMapper.urlForLicense("cc0-1.0") == "https://creativecommons.org/publicdomain/zero/1.0/")
    }

    @Test("Maps AI model specific licenses")
    func testAIModelLicenses() {
        // LLaMA licenses
        #expect(LicenseMapper.urlForLicense("llama2") == "https://ai.meta.com/llama/license/")
        #expect(LicenseMapper.urlForLicense("llama3") == "https://llama.meta.com/llama3/license/")
        #expect(LicenseMapper.urlForLicense("llama3.1") == "https://llama.meta.com/llama3_1/license/")
        #expect(LicenseMapper.urlForLicense("llama3.2") == "https://llama.meta.com/llama3_2/license/")
        #expect(LicenseMapper.urlForLicense("llama3.3") == "https://llama.meta.com/llama3_3/license/")

        // Google Gemma
        #expect(LicenseMapper.urlForLicense("gemma") == "https://ai.google.dev/gemma/terms")

        // DeepSeek
        #expect(
            LicenseMapper.urlForLicense("deepseek") ==
            "https://github.com/deepseek-ai/DeepSeek-V2/blob/main/LICENSE-MODEL"
        )
        #expect(
            LicenseMapper.urlForLicense("deepseek-license") ==
            "https://github.com/deepseek-ai/DeepSeek-V2/blob/main/LICENSE-MODEL"
        )

        // OpenRAIL licenses
        #expect(LicenseMapper.urlForLicense("openrail") == "https://www.licenses.ai/ai-pubs-open-rails-vz1")
        #expect(LicenseMapper.urlForLicense("openrail-m") == "https://www.licenses.ai/ai-model-openrail-m-vz1")
        #expect(LicenseMapper.urlForLicense("openrail++") == "https://www.licenses.ai/ai-pubs-open-rails-vz1")
        #expect(
            LicenseMapper.urlForLicense("creativeml-openrail-m") ==
            "https://huggingface.co/spaces/CompVis/stable-diffusion-license"
        )

        // BigScience
        #expect(
            LicenseMapper.urlForLicense("bigscience-bloom-rail-1.0") ==
            "https://bigscience.huggingface.co/blog/the-bigscience-rail-license"
        )

        // Other AI licenses
        #expect(
            LicenseMapper.urlForLicense("stability-ai-community") ==
            "https://huggingface.co/stabilityai/stable-diffusion-2/blob/main/LICENSE-MODEL"
        )
    }

    @Test("Handles nil and empty inputs")
    func testNilAndEmptyInputs() {
        #expect(LicenseMapper.urlForLicense(nil) == nil)
        #expect(LicenseMapper.urlForLicense("") == nil)
        #expect(LicenseMapper.urlForLicense(" ") == nil)
        #expect(LicenseMapper.urlForLicense("   ") == nil)
    }

    @Test("Returns nil for unknown licenses")
    func testUnknownLicenses() {
        #expect(LicenseMapper.urlForLicense("unknown-license") == nil)
        #expect(LicenseMapper.urlForLicense("my-custom-license") == nil)
        #expect(LicenseMapper.urlForLicense("proprietary") == nil)
        #expect(LicenseMapper.urlForLicense("commercial") == nil)
    }

    @Test("Handles case variations and formatting")
    func testCaseVariations() {
        // Test various case combinations
        #expect(LicenseMapper.urlForLicense("apache-2.0") == LicenseMapper.urlForLicense("Apache-2.0"))
        #expect(LicenseMapper.urlForLicense("MIT") == LicenseMapper.urlForLicense("mit"))
        #expect(LicenseMapper.urlForLicense("GPL-3.0") == LicenseMapper.urlForLicense("gpl-3.0"))

        // Test with extra spaces (should be trimmed)
        #expect(LicenseMapper.urlForLicense(" apache-2.0 ") == "https://www.apache.org/licenses/LICENSE-2.0")
        #expect(LicenseMapper.urlForLicense("  mit  ") == "https://opensource.org/licenses/MIT")
    }

    @Test("Maps other common licenses")
    func testOtherCommonLicenses() {
        // Unlicense
        #expect(LicenseMapper.urlForLicense("unlicense") == "https://unlicense.org/")

        // WTFPL
        #expect(LicenseMapper.urlForLicense("wtfpl") == "https://www.wtfpl.net/about/")

        // Artistic License
        #expect(LicenseMapper.urlForLicense("artistic-2.0") == "https://opensource.org/licenses/Artistic-2.0")

        // Eclipse Public License
        #expect(LicenseMapper.urlForLicense("epl-2.0") == "https://www.eclipse.org/legal/epl-2.0/")
        #expect(LicenseMapper.urlForLicense("epl-1.0") == "https://www.eclipse.org/legal/epl-v10.html")

        // Zlib License
        #expect(LicenseMapper.urlForLicense("zlib") == "https://opensource.org/licenses/Zlib")
    }

    @Test("All mapped licenses return valid URLs")
    func testAllMappedLicensesReturnValidURLs() {
        let testLicenses: [String] = [
            "apache-2.0", "mit", "gpl-3.0", "lgpl-3.0", "bsd-3-clause",
            "mpl-2.0", "cc-by-4.0", "llama2", "gemma", "openrail-m"
        ]

        for license in testLicenses {
            let url: String? = LicenseMapper.urlForLicense(license)
            #expect(url != nil, "License '\(license)' should have a URL")

            if let url {
                #expect(url.hasPrefix("http://") || url.hasPrefix("https://"),
                       "URL for license '\(license)' should start with http:// or https://")
                #expect(!url.isEmpty, "URL for license '\(license)' should not be empty")
            }
        }
    }
}
