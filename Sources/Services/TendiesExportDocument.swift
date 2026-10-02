import SwiftUI
import UniformTypeIdentifiers

struct TendiesExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    init() {}
    init(configuration: ReadConfiguration) throws {}
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Export is handled by the workspace archive service. This document is a placeholder
        // required by SwiftUI's fileExporter API; the next iteration will use a custom exporter.
        FileWrapper(regularFileWithContents: Data())
    }
}
