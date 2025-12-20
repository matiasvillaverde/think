import CoreGraphics
import Foundation
import PDFKit
import Rag

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension RagTests {
    func createPDFFile(with text: String) throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
        let pdfURL: URL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")

        #if canImport(UIKit)
        try createPDFWithUIKit(text: text, url: pdfURL)
        #else
        try createPDFWithAppKit(text: text, url: pdfURL)
        #endif

        return pdfURL
    }

    #if canImport(UIKit)
    private func createPDFWithUIKit(text: String, url: URL) throws {
        let format: UIGraphicsPDFRendererFormat = UIGraphicsPDFRendererFormat()
        let bounds: CGRect = createStandardPageBounds()
        let renderer: UIGraphicsPDFRenderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            let attributedString: NSAttributedString = createAttributedString(text: text)
            let drawRect: CGRect = createDrawRect(from: bounds)
            attributedString.draw(in: drawRect)
        }
    }
    #else
    private func createPDFWithAppKit(text: String, url: URL) throws {
        var mediaBox: CGRect = createStandardPageBounds()
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw NSError(
                domain: "RagTests",
                code: Constants.PDF.creationErrorCode,
                userInfo: [NSLocalizedDescriptionKey: "Could not create CGContext"]
            )
        }

        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        let cgContext: NSGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = cgContext

        let attributedString: NSAttributedString = createAttributedString(text: text)
        let drawRect: CGRect = createDrawRect(from: mediaBox)
        attributedString.draw(in: drawRect)

        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
    }
    #endif

    private func createStandardPageBounds() -> CGRect {
        CGRect(
            x: Constants.Geometry.origin,
            y: Constants.Geometry.origin,
            width: Constants.PDF.standardPageWidth,
            height: Constants.PDF.standardPageHeight
        )
    }

    private func createAttributedString(text: String) -> NSAttributedString {
        #if canImport(UIKit)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: Constants.PDF.defaultFontSize)
        ]
        #else
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: Constants.PDF.defaultFontSize)
        ]
        #endif
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func createDrawRect(from bounds: CGRect) -> CGRect {
        CGRect(
            x: Constants.PDF.standardMargin,
            y: Constants.PDF.standardMargin,
            width: bounds.width - Constants.PDF.marginOffset,
            height: bounds.height - Constants.PDF.marginOffset
        )
    }
}
