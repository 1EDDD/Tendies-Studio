import SwiftUI
import PhotosUI

struct NewProjectSheet: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = "Untitled Wallpaper"
    @State private var target: WallpaperTarget = .iPadPortrait
    @State private var customWidth = "810"
    @State private var customHeight = "1080"
    @State private var imageData: Data?
    @State private var imageName = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var showingFiles = false
    @State private var showingPath = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Project name", text: $name)

                    Picker("Target", selection: $target) {
                        ForEach(WallpaperTarget.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }

                    if target == .custom {
                        HStack {
                            Text("Width")
                            Spacer()
                            TextField("810", text: $customWidth)
                                .frame(width: 90)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text("Height")
                            Spacer()
                            TextField("1080", text: $customHeight)
                                .frame(width: 90)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                Section("Starting image") {
                    HStack(spacing: 10) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Photos", systemImage: "photo.on.rectangle.angled")
                        }
                        .onChange(of: photoItem) { _, item in
                            guard let item else { return }
                            Task {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    imageData = data
                                    imageName = "Photo"
                                }
                            }
                        }

                        Button { showingFiles = true } label: {
                            Label("Files", systemImage: "folder")
                        }

                        Button { showingPath = true } label: {
                            Label("Path", systemImage: "link")
                        }
                    }

                    if imageData != nil {
                        Label(imageName.isEmpty ? "Image selected" : imageName, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("Leave this empty to start with a blank canvas.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text("The project is generated locally with editable CAML layers. Compatibility still needs testing against the target PosterBoard/iPadOS build.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        workspace.createNewProject(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Wallpaper" : name,
                            target: target,
                            customWidth: Double(customWidth),
                            customHeight: Double(customHeight),
                            imageData: imageData
                        )
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .fileImporter(
                isPresented: $showingFiles,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first,
                   let data = try? Data(contentsOf: url) {
                    imageData = data
                    imageName = url.deletingPathExtension().lastPathComponent
                }
            }
            .sheet(isPresented: $showingPath) {
                ManualPathSheet { path in
                    let url = URL(fileURLWithPath: path)
                    guard let data = try? Data(contentsOf: url) else { return }
                    imageData = data
                    imageName = url.deletingPathExtension().lastPathComponent
                }
            }
        }
        .frame(minWidth: 650, minHeight: 520)
    }
}
