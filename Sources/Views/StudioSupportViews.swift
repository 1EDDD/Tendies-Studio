import SwiftUI
import PhotosUI
import UIKit

struct AssetsStudioView: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @State private var showingImport = false
    @State private var showingPath = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Assets").font(.largeTitle.bold())
                    Text("Local media used by this wallpaper project.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { showingImport = true } label: {
                    Label("Import Image", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                Button { showingPath = true } label: {
                    Label("Manual Path", systemImage: "link")
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 16)], spacing: 16) {
                    ForEach(workspace.layers.filter { $0.imageSource != nil }) { layer in
                        VStack(alignment: .leading, spacing: 8) {
                            if let path = layer.imageFilePath,
                               let image = UIImage(contentsOfFile: path) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 180)
                                    .frame(maxWidth: .infinity)
                                    .background(.black.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Text(layer.name).font(.headline).lineLimit(1)
                            Text(layer.surface.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                workspace.selectedLayerID = layer.id
                                workspace.activePanel = .design
                            } label: {
                                Label("Edit Layer", systemImage: "slider.horizontal.3")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(20)
            }
        }
        .sheet(isPresented: $showingImport) {
            MediaImportSheet(title: "Import Image") { data, name in
                workspace.addImageFromData(data, preferredName: name)
            }
        }
        .sheet(isPresented: $showingPath) {
            ManualPathSheet { path in workspace.addImageFromPath(path) }
        }
    }
}

struct PackageStudioView: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @State private var selectedCAML: String?
    @State private var text = ""

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selectedCAML) {
                Section("CAML") {
                    ForEach(
                        workspace.entries.filter { $0.fileExtension == "caml" }.map(\.path),
                        id: \.self
                    ) { path in
                        Text(path)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(2)
                            .tag(Optional(path))
                    }
                }
                Section("Package Files") {
                    ForEach(workspace.entries.filter { !$0.isDirectory }.prefix(100)) { entry in
                        Text(entry.path)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: 330)

            Divider()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CAML Inspector").font(.title2.bold())
                        Text(selectedCAML ?? "Choose a CAML file")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let selectedCAML {
                        Button("Save") {
                            workspace.saveCAML(text: text, relativePath: selectedCAML)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(18)
                Divider()

                if selectedCAML != nil {
                    TextEditor(text: $text)
                        .font(.system(.footnote, design: .monospaced))
                        .padding(12)
                } else {
                    ContentUnavailableView(
                        "No CAML selected",
                        systemImage: "curlybraces",
                        description: Text("Select a CAML document from the package.")
                    )
                }
            }
        }
        .onChange(of: selectedCAML) { _, newValue in
            guard let newValue else { return }
            text = workspace.loadCAML(relativePath: newValue) ?? ""
        }
    }
}

struct ValidationStudioView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Validation").font(.largeTitle.bold())
                Text("Structural checks are local. A passing check does not guarantee compatibility with every OS build.")
                    .foregroundStyle(.secondary)

                ValidationCard(
                    title: "Descriptor / container",
                    passed: workspace.entries.contains {
                        $0.path.hasPrefix("descriptors/") || $0.path.hasPrefix("container/")
                    },
                    detail: "A supported package root was found."
                )

                ValidationCard(
                    title: "Wallpaper metadata",
                    passed: workspace.entries.contains { $0.path.hasSuffix("Wallpaper.plist") },
                    detail: "Wallpaper.plist detected."
                )

                ValidationCard(
                    title: "CAML layers",
                    passed: !workspace.layers.isEmpty,
                    detail: "\(workspace.layers.count) editable CALayer resources detected."
                )

                ValidationCard(
                    title: "Image assets",
                    passed: workspace.layers.contains { $0.imageSource != nil },
                    detail: "At least one image layer is available."
                )
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(28)
        }
    }
}

struct ValidationCard: View {
    let title: String
    let passed: Bool
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(passed ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct MediaImportSheet: View {
    let title: String
    let completion: (Data, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var photoItem: PhotosPickerItem?
    @State private var showingFiles = false
    @State private var showingPath = false
    @State private var loading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        sourceCard("Photos", "photo.on.rectangle.angled")
                    }
                    .onChange(of: photoItem) { _, item in
                        guard let item else { return }
                        loading = true
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                completion(data, "Photo")
                                dismiss()
                            }
                            loading = false
                        }
                    }

                    Button { showingFiles = true } label: {
                        sourceCard("Files", "folder")
                    }

                    Button { showingPath = true } label: {
                        sourceCard("Manual Path", "link")
                    }
                }
                .padding(.horizontal)

                if loading {
                    ProgressView("Importing…")
                } else {
                    Text("Photos, Files and manual filesystem paths are supported.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingFiles,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    do {
                        let data = try MediaImportService.readData(from: url)
                        completion(data, MediaImportService.suggestedName(for: url))
                        dismiss()
                    } catch {
                    }
                }
            }
            .sheet(isPresented: $showingPath) {
                ManualPathSheet { path in
                    let url = URL(fileURLWithPath: path)
                    if let data = try? MediaImportService.readData(from: url) {
                        completion(data, MediaImportService.suggestedName(for: url))
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 270)
    }

    private func sourceCard(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: icon).font(.title2)
            Text(title).font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct ManualPathSheet: View {
    let completion: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var path = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Image path") {
                    TextField("/path/to/image.png", text: $path)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                }
                Section {
                    Text("A manually entered path cannot bypass iOS file permissions. The location still has to be readable by the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Manual Path")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Use Path") {
                        completion(path)
                        dismiss()
                    }
                    .disabled(path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 560, minHeight: 270)
    }
}
