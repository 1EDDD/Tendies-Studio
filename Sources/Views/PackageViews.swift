import SwiftUI
import UIKit

struct PackageOverviewView: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Package overview").font(.title.bold())
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 14)], spacing: 14) {
                    MetricCard(title: "Files", value: "\(workspace.entries.filter { !$0.isDirectory }.count)", icon: "doc")
                    MetricCard(title: "Folders", value: "\(workspace.entries.filter { $0.isDirectory }.count)", icon: "folder")
                    MetricCard(title: "Images", value: "\(workspace.entries.filter { ["png","jpg","jpeg","heic"].contains($0.fileExtension) }.count)", icon: "photo")
                    MetricCard(title: "CAML / XML", value: "\(workspace.entries.filter { ["caml","xml"].contains($0.fileExtension) }.count)", icon: "chevron.left.forwardslash.chevron.right")
                }
                GroupBox("Package layout") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(workspace.entries.filter { $0.path.split(separator: "/").count <= 2 }.prefix(12)) { entry in
                            Label(entry.name, systemImage: entry.isDirectory ? "folder.fill" : "doc")
                                .font(.subheadline).foregroundStyle(entry.isDirectory ? .cyan : .secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
                }
                Text("The original package files are retained during editing. Unsupported metadata is not rewritten.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

struct PackageBrowserView: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    var body: some View {
        List(workspace.entries) { entry in
            HStack(spacing: 10) {
                Image(systemName: entry.isDirectory ? "folder.fill" : icon(for: entry.fileExtension))
                    .foregroundStyle(entry.isDirectory ? .cyan : .secondary)
                Text(entry.path).font(.system(.caption, design: .monospaced)).lineLimit(2)
                Spacer()
                if !entry.isDirectory {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(entry.uncompressedSize), countStyle: .file))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }.listStyle(.inset)
    }

    private func icon(for ext: String) -> String {
        switch ext {
        case "png", "jpg", "jpeg", "heic": return "photo"
        case "plist": return "list.bullet.rectangle"
        case "xml", "caml": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }
}

struct AssetBrowserView: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @State private var showingImporter = false
    @State private var targetPath: String?
    private let columns = [GridItem(.adaptive(minimum: 170), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(workspace.entries.filter {
                    ["png", "jpg", "jpeg", "heic"].contains($0.fileExtension)
                }) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        if let root = workspace.workspaceURL,
                           let image = UIImage(contentsOfFile: root.appendingPathComponent(entry.path).path) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .frame(maxWidth: .infinity)
                                .background(.black.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.quaternary)
                                .frame(height: 150)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                )
                        }

                        Text(entry.name)
                            .font(.caption)
                            .lineLimit(1)

                        Button {
                            targetPath = entry.path
                            showingImporter = true
                        } label: {
                            Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(workspace.isBusy)
                    }
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.vertical, 4)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first, let targetPath {
                workspace.replaceImage(at: targetPath, with: url)
            }
            if case .failure(let error) = result {
                workspace.errorMessage = error.localizedDescription
            }
            targetPath = nil
        }
    }
}

struct ValidationView: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    private var files: [String] { workspace.entries.filter { !$0.isDirectory }.map { $0.path } }
    private var hasDescriptors: Bool { files.contains { $0.hasPrefix("descriptors/") } }
    private var hasContainer: Bool { files.contains { $0.hasPrefix("container/") } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Package checks").font(.title2.bold())
            check("Archive extracted", true, "The ZIP-based package was readable.")
            check("Descriptor or container root", hasDescriptors || hasContainer, "Expected a descriptors/ or container/ directory.")
            check("CAML resources", files.contains { $0.hasSuffix(".caml") }, "No CAML files were detected.")
            check("Wallpaper metadata", files.contains { $0.hasSuffix("Wallpaper.plist") }, "No Wallpaper.plist was detected.")
            Text("These are structural checks only. They do not prove compatibility with a particular iPadOS build or guarantee that a restore tool will accept the package.")
                .font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
            Spacer()
        }
    }
    private func check(_ title: String, _ passed: Bool, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(passed ? .green : .orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(passed ? "Detected" : detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    var body: some View {
        GroupBox {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(value).font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text(title).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: icon).font(.title2).foregroundStyle(.cyan)
            }.padding(5)
        }
    }
}

struct InspectorPlaceholder: View {
    let title: String
    let subtitle: String
    var body: some View {
        ContentUnavailableView(title, systemImage: "slider.horizontal.3", description: Text(subtitle))
    }
}
