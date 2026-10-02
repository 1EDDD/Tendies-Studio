import Foundation
import ZIPFoundation

enum TendiesArchiveError: LocalizedError {
    case invalidArchive
    case missingWorkspace
    case unsafePath(String)
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .invalidArchive: return "This file is not a readable ZIP-based Tendies package."
        case .missingWorkspace: return "No package is currently open."
        case .unsafePath(let path): return "The archive contains an unsafe path: \(path)"
        case .exportFailed: return "The package could not be exported."
        }
    }
}

struct TendiesArchive {
    static func extract(_ archiveURL: URL, to destination: URL) throws -> [PackageEntry] {
        let access = archiveURL.startAccessingSecurityScopedResource()
        defer { if access { archiveURL.stopAccessingSecurityScopedResource() } }

        guard let archive = Archive(url: archiveURL, accessMode: .read) else {
            throw TendiesArchiveError.invalidArchive
        }

        let root = destination.standardizedFileURL
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var entries: [PackageEntry] = []

        for entry in archive {
            let relative = entry.path
            let components = relative.split(separator: "/")
            guard !relative.hasPrefix("/"),
                  !components.contains(".."),
                  !relative.contains("\\") else {
                throw TendiesArchiveError.unsafePath(relative)
            }

            let output = root.appendingPathComponent(relative).standardizedFileURL
            guard output.path.hasPrefix(root.path + "/") || output == root else {
                throw TendiesArchiveError.unsafePath(relative)
            }

            if entry.type == .directory {
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            } else {
                try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
                _ = try archive.extract(entry, to: output)
            }
            entries.append(PackageEntry(
                id: relative,
                path: relative,
                isDirectory: entry.type == .directory,
                uncompressedSize: entry.uncompressedSize
            ))
        }
        return entries.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    static func create(from folder: URL, to destination: URL) throws {
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }

        guard let archive = Archive(url: destination, accessMode: .create) else {
            throw TendiesArchiveError.exportFailed
        }

        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { throw TendiesArchiveError.exportFailed }

        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let relative = String(fileURL.path.dropFirst(folder.path.count + 1))
            try archive.addEntry(with: relative, fileURL: fileURL, compressionMethod: .deflate)
        }
    }
}
