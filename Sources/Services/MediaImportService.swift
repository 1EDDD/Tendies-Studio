import Foundation

enum MediaImportService {
    static func readData(from url: URL) throws -> Data {
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try Data(contentsOf: url, options: [.mappedIfSafe])
    }

    static func suggestedName(for url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        return name.isEmpty ? "Image" : name
    }
}
