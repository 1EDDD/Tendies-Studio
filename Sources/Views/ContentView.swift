import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @State private var showingOpen = false
    @State private var showingNew = false
    @State private var showingExport = false
    @State private var exportDocument: TendiesExportDocument?

    var body: some View {
        Group {
            if workspace.workspaceURL == nil {
                WelcomeStudioView(
                    openAction: { showingOpen = true },
                    newAction: { showingNew = true }
                )
            } else {
                editorShell
            }
        }
        .tint(.cyan)
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $showingOpen,
            allowedContentTypes: [.tendies, .zip, .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                workspace.open(url)
            }
            if case .failure(let error) = result {
                workspace.errorMessage = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $showingExport,
            document: exportDocument,
            contentType: .tendies,
            defaultFilename: "\(workspace.projectName).tendies"
        ) { result in
            if case .failure(let error) = result {
                workspace.errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showingNew) {
            NewProjectSheet()
        }
        .alert("Tendies Studio", isPresented: Binding(
            get: { workspace.errorMessage != nil },
            set: { if !$0 { workspace.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { workspace.errorMessage = nil }
        } message: {
            Text(workspace.errorMessage ?? "")
        }
    }

    private var editorShell: some View {
        NavigationSplitView {
            StudioSidebar(
                openAction: { showingOpen = true },
                newAction: { showingNew = true }
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 290)
        } detail: {
            VStack(spacing: 0) {
                topBar
                Divider()

                switch workspace.activePanel {
                case .design:
                    StudioEditorView()
                case .assets:
                    AssetsStudioView()
                case .package:
                    PackageStudioView()
                case .validation:
                    ValidationStudioView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.96))
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { showingNew = true } label: {
                Label("New", systemImage: "plus")
            }
            .buttonStyle(.borderless)

            Button { showingOpen = true } label: {
                Label("Open", systemImage: "folder")
            }
            .buttonStyle(.borderless)

            Divider().frame(height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.projectName)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(Int(workspace.projectSettings.width)) × \(Int(workspace.projectSettings.height)) • \(workspace.status)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                exportCurrentProject()
            } label: {
                Label("Export .tendies", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .disabled(workspace.isBusy)

            Circle()
                .fill(workspace.isBusy ? .orange : .green)
                .frame(width: 8, height: 8)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    private func exportCurrentProject() {
        guard let root = workspace.workspaceURL else { return }
        workspace.isBusy = true

        Task {
            do {
                let output = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(workspace.projectName).tendies")
                try? FileManager.default.removeItem(at: output)

                try await Task.detached(priority: .userInitiated) {
                    try TendiesArchive.create(from: root, to: output)
                }.value

                exportDocument = TendiesExportDocument(data: try Data(contentsOf: output))
                showingExport = true
            } catch {
                workspace.errorMessage = error.localizedDescription
            }
            workspace.isBusy = false
        }
    }
}

struct StudioSidebar: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    let openAction: () -> Void
    let newAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                Text("Tendies Studio")
                    .font(.title3.weight(.bold))
                Spacer()
            }
            .padding(18)

            Divider()

            VStack(spacing: 5) {
                sideItem(.design)
                sideItem(.assets)
                sideItem(.package)
                sideItem(.validation)
            }
            .padding(10)

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text("Local workspace").font(.caption.weight(.medium))
                }

                Button(action: newAction) {
                    Label("New Project", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)

                Button(action: openAction) {
                    Label("Open .tendies", systemImage: "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
            .padding(14)
        }
        .background(Color.black.opacity(0.84))
    }

    private func sideItem(_ panel: StudioPanel) -> some View {
        Button {
            workspace.activePanel = panel
        } label: {
            HStack(spacing: 12) {
                Image(systemName: panel.symbol).frame(width: 20)
                Text(panel.title)
                Spacer()
                if workspace.activePanel == panel {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(workspace.activePanel == panel ? Color.cyan.opacity(0.13) : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct WelcomeStudioView: View {
    let openAction: () -> Void
    let newAction: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color(red: 0.02, green: 0.05, blue: 0.07), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 66, weight: .light))
                    .foregroundStyle(.cyan)

                Text("Tendies Studio")
                    .font(.system(size: 42, weight: .bold, design: .rounded))

                Text("Design, inspect and export PosterBoard wallpaper packages in a native iPad workspace.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 700)

                HStack(spacing: 12) {
                    Button(action: newAction) {
                        Label("Create New", systemImage: "plus")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: openAction) {
                        Label("Open Package", systemImage: "folder")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 28) {
                    feature("Layer editor", "Canvas + transforms")
                    feature("Media sources", "Photos • Files • path")
                    feature("CAML", "Low-level inspection")
                }
                .padding(.top, 15)
            }
            .padding(40)
        }
    }

    private func feature(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: 175, alignment: .leading)
    }
}
