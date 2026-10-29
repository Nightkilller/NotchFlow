import Foundation
import PDFKit

// MARK: - PDF Import Service

enum PDFImportService {
    
    /// Extracts text from a PDF document using PDFKit.
    /// - Parameter url: Local file URL to the PDF.
    /// - Returns: Cleaned extracted text.
    static func parse(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw AppError.fileReadFailed(url.lastPathComponent)
        }
        
        guard document.pageCount > 0 else {
            throw AppError.emptyDocument
        }
        
        var fullText = ""
        
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            if let pageString = page.string {
                let trimmed = pageString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    fullText += trimmed + "\n\n"
                }
            }
        }
        
        let cleaned = DocumentCleaningService.clean(fullText)
        guard !cleaned.isEmpty else {
            // PDF may be image-only / scanned without OCR text
            throw AppError.pdfExtractionFailed
        }
        
        return cleaned
    }
}
