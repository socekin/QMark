import SwiftUI
import UniformTypeIdentifiers

// MARK: - Custom UTType Definitions

extension UTType {
    static let qmarkMarkdown: UTType = UTType("net.daringfireball.markdown")
        ?? UTType(filenameExtension: "md", conformingTo: .plainText)
        ?? .plainText
    static let qmarkMdx = UTType("com.qmark.mdx") ?? UTType(filenameExtension: "mdx", conformingTo: .plainText) ?? .plainText
    static let qmarkRmd = UTType("com.qmark.rmd") ?? UTType(filenameExtension: "rmd", conformingTo: .plainText) ?? .plainText
    static let qmarkMdown = UTType("com.qmark.mdown") ?? UTType(filenameExtension: "mdown", conformingTo: .plainText) ?? .plainText
    static let qmarkMkd = UTType("com.qmark.mkd") ?? UTType(filenameExtension: "mkd", conformingTo: .plainText) ?? .plainText
}

// MARK: - MarkdownDocument

final class MarkdownDocument: ReferenceFileDocument, @unchecked Sendable {

    static var readableContentTypes: [UTType] {
        [.qmarkMarkdown, .qmarkMdx, .qmarkRmd, .qmarkMdown, .qmarkMkd, .plainText]
    }

    static var writableContentTypes: [UTType] {
        [.qmarkMarkdown]
    }

    @Published var text: String

    /// Create empty document
    init() {
        self.text = ""
    }

    /// Read from file
    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    /// Save snapshot
    func snapshot(contentType: UTType) throws -> String {
        text
    }

    /// Write to file
    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = snapshot.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
