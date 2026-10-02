import Foundation
import SwiftUI

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published var projectName = "Untitled Wallpaper"
    @Published var entries: [PackageEntry] = []
    @Published var workspaceURL: URL?
    @Published var sourceURL: URL?
    @Published var selectedEntry: PackageEntry?
    @Published var status = "Ready"
    @Published var errorMessage: String?
    @Published var isBusy = false

    var rootURL: URL? { workspaceURL }

    func open(_ url: URL) {
        isBusy = true
        status = "Opening package…"
        errorMessage = nil
        Task {
            do {
                let root = FileManager.default.temporaryDirectory
                    .appendingPathComponent("TendiesStudio-\(UUID().uuidString)", isDirectory: true)
                let found = try await Task.detached(priority: .userInitiated) {
                    try TendiesArchive.extract(url, to: root)
                }.value
                workspaceURL = root
                sourceURL = url
                projectName = url.deletingPathExtension().lastPathComponent
                entries = found
                selectedEntry = nil
                status = "Imported \(found.filter { !$0.isDirectory }.count) files"
            } catch {
                errorMessage = error.localizedDescription
                status = "Import failed"
            }
            isBusy = false
        }
    }

    func export(to url: URL) {
        guard let root = workspaceURL else {
            errorMessage = TendiesArchiveError.missingWorkspace.localizedDescription
            return
        }
        isBusy = true
        status = "Building Tendies package…"
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try TendiesArchive.create(from: root, to: url)
                }.value
                status = "Exported successfully"
            } catch {
                errorMessage = error.localizedDescription
                status = "Export failed"
            }
            isBusy = false
        }
    }

    func refresh() {
        guard let root = workspaceURL else { return }
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey])
        var refreshed: [PackageEntry] = []
        while let url = enumerator?.nextObject() as? URL {
            let relative = String(url.path.dropFirst(root.path.count + 1))
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            refreshed.append(PackageEntry(
                id: relative,
                path: relative,
                isDirectory: values?.isDirectory ?? false,
                uncompressedSize: UInt64(values?.fileSize ?? 0)
            ))
        }
        entries = refreshed.sorted { $0.path < $1.path }
    }
}
