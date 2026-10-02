import Foundation

struct PackageEntry: Identifiable, Hashable {
    let id: String
    let path: String
    let isDirectory: Bool
    let uncompressedSize: UInt64

    var name: String { URL(fileURLWithPath: path).lastPathComponent }
    var fileExtension: String { URL(fileURLWithPath: path).pathExtension.lowercased() }
}
