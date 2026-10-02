import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let tendies = UTType(exportedAs: "com.1eddd.tendies", conformingTo: .zip)
}

struct TendiesExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.tendies, .zip, .data] }
    let data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
