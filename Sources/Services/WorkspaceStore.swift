import Foundation
import SwiftUI
import UIKit

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published var projectName = "Untitled Wallpaper"
    @Published var entries: [PackageEntry] = []
    @Published var workspaceURL: URL?
    @Published var sourceURL: URL?
    @Published var layers: [StudioLayer] = []
    @Published var selectedLayerID: String?
    @Published var projectSettings = StudioProjectSettings(
        name: "Untitled Wallpaper",
        target: .iPadPortrait,
        width: 810,
        height: 1080
    )
    @Published var status = "Ready"
    @Published var errorMessage: String?
    @Published var isBusy = false
    @Published var activePanel: StudioPanel = .design

    var rootURL: URL? { workspaceURL }

    var selectedLayer: StudioLayer? {
        guard let selectedLayerID else { return nil }
        return layers.first { $0.id == selectedLayerID }
    }

    func open(_ url: URL) {
        isBusy = true
        status = "Opening package…"
        errorMessage = nil

        Task {
            do {
                let projectRoot = try makeProjectRoot(named: url.deletingPathExtension().lastPathComponent)
                let found = try await Task.detached(priority: .userInitiated) {
                    try TendiesArchive.extract(url, to: projectRoot)
                }.value

                workspaceURL = projectRoot
                sourceURL = url
                projectName = url.deletingPathExtension().lastPathComponent
                projectSettings.name = projectName
                entries = found
                try reloadLayers()
                selectedLayerID = layers.first?.id
                activePanel = .design
                status = "Ready"
            } catch {
                errorMessage = error.localizedDescription
                status = "Import failed"
            }
            isBusy = false
        }
    }

    func createNewProject(
        name: String,
        target: WallpaperTarget,
        customWidth: Double? = nil,
        customHeight: Double? = nil,
        imageData: Data? = nil
    ) {
        isBusy = true
        errorMessage = nil
        status = "Creating project…"

        Task {
            do {
                let size = target == .custom
                    ? CGSize(width: customWidth ?? 810, height: customHeight ?? 1080)
                    : target.size

                let root = try makeProjectRoot(named: name)
                try TendiesProjectFactory.create(
                    at: root,
                    name: name,
                    size: size,
                    logicalScreenClass: target.logicalScreenClass,
                    imageData: imageData
                )

                workspaceURL = root
                sourceURL = nil
                projectName = name
                projectSettings = StudioProjectSettings(
                    name: name,
                    target: target,
                    width: size.width,
                    height: size.height
                )
                refresh()
                try reloadLayers()
                selectedLayerID = layers.first?.id
                activePanel = .design
                status = "New project ready"
            } catch {
                errorMessage = error.localizedDescription
                status = "Project creation failed"
            }
            isBusy = false
        }
    }

    func createFromImage(_ imageURL: URL) {
        let access = imageURL.startAccessingSecurityScopedResource()
        defer { if access { imageURL.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: imageURL) else {
            errorMessage = "The selected image could not be read."
            return
        }

        createNewProject(
            name: imageURL.deletingPathExtension().lastPathComponent + " Wallpaper",
            target: .iPadPortrait,
            imageData: data
        )
    }

    func addImageFromData(_ data: Data, preferredName: String = "Image") {
        guard let root = workspaceURL else {
            errorMessage = "Create or open a project first."
            return
        }

        isBusy = true
        status = "Adding image…"

        Task {
            do {
                let targetSurface: LayerSurface = selectedLayer?.surface ?? .background
                let targetCAML = layers.first(where: { $0.surface == targetSurface })?.camlPath
                    ?? layers.first?.camlPath

                guard let camlPath = targetCAML else {
                    throw TendiesArchiveError.exportFailed
                }

                let caFolder = root
                    .appendingPathComponent(camlPath)
                    .deletingLastPathComponent()
                let assets = caFolder.appendingPathComponent("assets", isDirectory: true)
                try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

                let sanitized = preferredName
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ":", with: "-")
                let filename = "\(sanitized)-\(UUID().uuidString.prefix(6)).png"
                let imageURL = assets.appendingPathComponent(filename)

                guard let image = UIImage(data: data), let png = image.pngData() else {
                    throw TendiesArchiveError.exportFailed
                }
                try png.write(to: imageURL, options: .atomic)

                try insertImageLayer(
                    id: UUID().uuidString.replacingOccurrences(of: "-", with: ""),
                    name: sanitized,
                    imageSource: "assets/\(filename)",
                    camlFile: root.appendingPathComponent(camlPath),
                    width: projectSettings.width,
                    height: projectSettings.height
                )

                try reloadLayers()
                selectedLayerID = layers.last?.id
                refresh()
                status = "Image added"
            } catch {
                errorMessage = error.localizedDescription
                status = "Image import failed"
            }
            isBusy = false
        }
    }

    func addImageFromPath(_ path: String) {
        let raw = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            errorMessage = "Enter a file path first."
            return
        }

        let normalized = raw.hasPrefix("file://")
            ? URL(string: raw)
            : URL(fileURLWithPath: raw)

        guard let url = normalized else {
            errorMessage = "That path is not a valid file URL."
            return
        }

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            errorMessage = "The path is not readable from this app. A filesystem path only works when the location is exposed to the app. Use Files or Photos for locations outside the app sandbox."
            return
        }

        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "The file could not be read."
            return
        }

        addImageFromData(data, preferredName: url.deletingPathExtension().lastPathComponent)
    }

    func replaceImage(for layerID: String, with data: Data) {
        guard let root = workspaceURL, let layer = layers.first(where: { $0.id == layerID }),
              let source = layer.imageSource else {
            errorMessage = "Select an image layer to replace."
            return
        }

        let url = root.appendingPathComponent(layer.caFolderPath)
            .appendingPathComponent(source)
            .standardizedFileURL

        guard url.path.hasPrefix(root.path + "/") else {
            errorMessage = "Unsafe asset path."
            return
        }

        guard let image = UIImage(data: data), let png = image.pngData() else {
            errorMessage = "The selected image could not be converted."
            return
        }

        do {
            try png.write(to: url, options: .atomic)
            refresh()
            status = "Image replaced"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateLayer(_ updated: StudioLayer) {
        guard let index = layers.firstIndex(where: { $0.id == updated.id }) else { return }
        layers[index] = updated
        guard let root = workspaceURL else { return }

        do {
            try CAMLService.writeLayer(updated, in: root)
            status = "Edited"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCAML(relativePath: String) -> String? {
        guard let root = workspaceURL else { return nil }
        return try? CAMLService.readText(relativePath: relativePath, in: root)
    }

    func saveCAML(text: String, relativePath: String) {
        guard let root = workspaceURL else { return }
        do {
            try CAMLService.writeText(text, relativePath: relativePath, in: root)
            try reloadLayers()
            status = "CAML saved"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() {
        guard let root = workspaceURL else { return }

        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: []
        )

        var refreshed: [PackageEntry] = []
        while let url = enumerator?.nextObject() as? URL {
            let relative = String(url.path.dropFirst(root.path.count + 1))
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            refreshed.append(
                PackageEntry(
                    id: relative,
                    path: relative,
                    isDirectory: values?.isDirectory ?? false,
                    uncompressedSize: UInt64(values?.fileSize ?? 0)
                )
            )
        }

        entries = refreshed.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private func reloadLayers() throws {
        guard let root = workspaceURL else { return }
        layers = try CAMLService.discoverLayers(in: root)
        if selectedLayerID == nil {
            selectedLayerID = layers.first?.id
        } else if !layers.contains(where: { $0.id == selectedLayerID }) {
            selectedLayerID = layers.first?.id
        }
    }

    private func insertImageLayer(
        id: String,
        name: String,
        imageSource: String,
        camlFile: URL,
        width: Double,
        height: Double
    ) throws {
        var xml = try String(contentsOf: camlFile, encoding: .utf8)
        let layer = """
        <CALayer id="\(id)" name="\(xmlEscape(name))" bounds="0 0 \(n(width)) \(n(height))" position="\(n(width / 2)) \(n(height / 2))" zPosition="100" geometryFlipped="0" opacity="1" transform.rotation.z="0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
          <contents><CGImage src="\(imageSource)"/></contents>
        </CALayer>
        """

        guard let end = xml.range(of: "</sublayers>") else {
            throw TendiesArchiveError.exportFailed
        }

        xml.insert(contentsOf: layer, at: end.lowerBound)
        try xml.write(to: camlFile, atomically: true, encoding: .utf8)
    }

    private func makeProjectRoot(named name: String) throws -> URL {
        let base = try applicationProjectsDirectory()
        let safe = name
            .replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = base.appendingPathComponent("\(safe.isEmpty ? "Untitled" : safe)-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func applicationProjectsDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("TendiesStudio/Projects", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func sanitize(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }

    private func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: """, with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func n(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.000001 { return String(Int(value.rounded())) }
        return String(format: "%.4f", value)
    }
}
