import Testing
import Foundation
@testable import NotchFlow

// MARK: - DocumentCleaningService Tests

@Suite("DocumentCleaningService")
struct DocumentCleaningServiceTests {
    
    @Test("Reconstructs hyphenated line wraps")
    func hyphenatedLineWraps() {
        let raw = "This is a demon-\nstration of text recon-\nstruction."
        let cleaned = DocumentCleaningService.clean(raw)
        
        #expect(cleaned.contains("demonstration"))
        #expect(cleaned.contains("reconstruction"))
        #expect(!cleaned.contains("demon-"))
    }
    
    @Test("Strips standalone page numbers and footers")
    func pageNumberRemoval() {
        let raw = """
        First paragraph text here.
        
        Page 1 of 5
        
        Second paragraph text here.
        
        42
        
        Third paragraph text here.
        """
        let cleaned = DocumentCleaningService.clean(raw)
        
        #expect(!cleaned.contains("Page 1 of 5"))
        #expect(!cleaned.contains("42"))
        #expect(cleaned.contains("First paragraph text here."))
        #expect(cleaned.contains("Second paragraph text here."))
        #expect(cleaned.contains("Third paragraph text here."))
    }
    
    @Test("Preserves genuine double-newline paragraph boundaries")
    func paragraphPreservation() {
        let raw = "Paragraph one is here.\n\nParagraph two is here.\n\nParagraph three is here."
        let cleaned = DocumentCleaningService.clean(raw)
        let paragraphs = cleaned.components(separatedBy: "\n\n")
        
        #expect(paragraphs.count == 3)
    }
    
    @Test("Preserves bullet points")
    func bulletListPreservation() {
        let raw = """
        Here are key items:
        • First point
        • Second point
        • Third point
        """
        let cleaned = DocumentCleaningService.clean(raw)
        
        #expect(cleaned.contains("• First point"))
        #expect(cleaned.contains("• Second point"))
        #expect(cleaned.contains("• Third point"))
    }
}

// MARK: - MarkdownImportService Tests

@Suite("MarkdownImportService")
struct MarkdownImportServiceTests {
    
    @Test("Cleans Markdown heading syntax while preserving text")
    func cleanHeadings() {
        let raw = "# Main Presentation\n\n## Section Overview\n\n### Key Takeaways"
        let cleaned = MarkdownImportService.cleanMarkdownSyntax(raw)
        
        #expect(!cleaned.contains("#"))
        #expect(cleaned.contains("Main Presentation"))
        #expect(cleaned.contains("Section Overview"))
        #expect(cleaned.contains("Key Takeaways"))
    }
    
    @Test("Strips bold and italic markers")
    func cleanBoldItalic() {
        let raw = "This is **very important** and this is *subtly emphasized*."
        let cleaned = MarkdownImportService.cleanMarkdownSyntax(raw)
        
        #expect(!cleaned.contains("**"))
        #expect(!cleaned.contains("*"))
        #expect(cleaned.contains("very important"))
        #expect(cleaned.contains("subtly emphasized"))
    }
    
    @Test("Converts markdown links to readable anchor text")
    func cleanLinks() {
        let raw = "Check out [NotchFlow Teleprompter](https://github.com/notchflow) for details."
        let cleaned = MarkdownImportService.cleanMarkdownSyntax(raw)
        
        #expect(cleaned.contains("Check out NotchFlow Teleprompter for details."))
        #expect(!cleaned.contains("https://github.com"))
    }
}

// MARK: - ScriptImportService Tests

@Suite("ScriptImportService")
struct ScriptImportServiceTests {
    
    @Test("Rejects unsupported file types with appropriate error")
    func unsupportedFileType() {
        let url = URL(fileURLWithPath: "/tmp/script.xyz")
        #expect(throws: AppError.self) {
            _ = try ScriptImportService.importDocument(from: url)
        }
    }
    
    @Test("Derives clean title from filename")
    func titleExtraction() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("annual_product_keynote.txt")
        let content = "Welcome everyone to our annual keynote presentation."
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        let (title, text) = try ScriptImportService.importDocument(from: fileURL)
        
        #expect(title == "Annual Product Keynote")
        #expect(text.contains("annual keynote presentation"))
        
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    @Test("Throws emptyDocument error for zero-byte files")
    func emptyFileError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("empty_test_file.txt")
        try "".write(to: fileURL, atomically: true, encoding: .utf8)
        
        #expect(throws: AppError.self) {
            _ = try ScriptImportService.importDocument(from: fileURL)
        }
        
        try? FileManager.default.removeItem(at: fileURL)
    }
}
