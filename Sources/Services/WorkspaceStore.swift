import Foundation
import SwiftUI
import UIKit

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

    func replaceImage(at relativePath: String, with imageURL: URL) {
        guard let root = workspaceURL else {
            errorMessage = TendiesArchiveError.missingWorkspace.localizedDescription
            return
        }

        isBusy = true
        status = "Replacing image…"

        Task {
            do {
                let access = imageURL.startAccessingSecurityScopedResource()
                defer { if access { imageURL.stopAccessingSecurityScopedResource() } }

                let target = root.appendingPathComponent(relativePath).standardizedFileURL
                guard target.path.hasPrefix(root.path + "/") else {
                    throw TendiesArchiveError.unsafePath(relativePath)
                }

                let data = try Data(contentsOf: imageURL)
                let ext = target.pathExtension.lowercased()

                if ext == "png" {
                    guard let image = UIImage(data: data), let png = image.pngData() else {
                        throw TendiesArchiveError.exportFailed
                    }
                    try png.write(to: target, options: .atomic)
                } else if ["jpg", "jpeg"].contains(ext) {
                    guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.95) else {
                        throw TendiesArchiveError.exportFailed
                    }
                    try jpeg.write(to: target, options: .atomic)
                } else {
                    try data.write(to: target, options: .atomic)
                }

                projectName = projectName.isEmpty ? imageURL.deletingPathExtension().lastPathComponent : projectName
                refresh()
                status = "Image replaced"
            } catch {
                errorMessage = error.localizedDescription
                status = "Image replacement failed"
            }
            isBusy = false
        }
    }

    /// Creates a new working project by cloning the currently open, known-good package
    /// and replacing its primary image with the selected image. This keeps all unknown
    /// PosterBoard metadata intact rather than synthesizing an arbitrary ZIP structure.
    func createFromImage(_ imageURL: URL) {
        guard let sourceRoot = workspaceURL else {
            errorMessage = "Open a known-good .tendies template first, then choose Create from Image."
            return
        }

        isBusy = true
        status = "Creating wallpaper from template…"

        Task {
            do {
                let newRoot = FileManager.default.temporaryDirectory
                    .appendingPathComponent("TendiesStudio-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.copyItem(at: sourceRoot, to: newRoot)

                let imagePath = primaryImagePath(in: newRoot)
                guard let imagePath else {
                    throw TendiesArchiveError.exportFailed
                }

                let access = imageURL.startAccessingSecurityScopedResource()
                defer { if access { imageURL.stopAccessingSecurityScopedResource() } }

                let target = newRoot.appendingPathComponent(imagePath)
                let data = try Data(contentsOf: imageURL)
                let ext = target.pathExtension.lowercased()

                if ext == "png" {
                    guard let image = UIImage(data: data), let png = image.pngData() else {
                        throw TendiesArchiveError.exportFailed
                    }
                    try png.write(to: target, options: .atomic)
                } else if ["jpg", "jpeg"].contains(ext) {
                    guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.95) else {
                        throw TendiesArchiveError.exportFailed
                    }
                    try jpeg.write(to: target, options: .atomic)
                } else {
                    try data.write(to: target, options: .atomic)
                }

                workspaceURL = newRoot
                sourceURL = nil
                projectName = imageURL.deletingPathExtension().lastPathComponent + " Wallpaper"
                selectedEntry = nil
                refresh()
                status = "Created from template"
            } catch {
                errorMessage = error.localizedDescription
                status = "Creation failed"
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

        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]
        )

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

    private func primaryImagePath(in root: URL) -> String? {
        let fileManager = FileManager.default
        let rootPath = root.path

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return nil
        }

        var candidates: [String] = []
        while let url = enumerator.nextObject() as? URL {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  values.isDirectory != true else { continue }

            let ext = url.pathExtension.lowercased()
            guard ["png", "jpg", "jpeg", "heic"].contains(ext) else { continue }

            let relative = String(url.path.dropFirst(rootPath.count + 1))
            candidates.append(relative)
        }

        func score(_ path: String) -> Int {
            let lower = path.lowercased()
            var value = 0
            if lower.contains("/background/") { value += 100 }
            if lower.contains("background") { value += 40 }
            if lower.contains("wallpaper") { value += 20 }
            if lower.hasSuffix(".png") { value += 5 }
            return value
        }

        return candidates.max { score($0) < score($1) }
    }
}
