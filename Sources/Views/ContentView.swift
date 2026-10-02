import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var selectedTab = "Workspace"
    @State private var exportDocument: TendiesExportDocument?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 250, ideal: 290)
        } detail: {
            workspaceView
        }
        .tint(.cyan)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.tendies, .zip, .data], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { workspace.open(url) }
            if case .failure(let error) = result { workspace.errorMessage = error.localizedDescription }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .tendies,
            defaultFilename: "\(workspace.projectName).tendies"
        ) { result in
            if case .failure(let error) = result { workspace.errorMessage = error.localizedDescription }
        }
        .alert("Tendies Studio", isPresented: Binding(
            get: { workspace.errorMessage != nil },
            set: { if !$0 { workspace.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { workspace.errorMessage = nil }
        } message: {
            Text(workspace.errorMessage ?? "")
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showingImporter = true } label: { Label("Open", systemImage: "folder") }
                Button { prepareExport() } label: { Label("Export", systemImage: "square.and.arrow.up") }
                    .disabled(workspace.workspaceURL == nil || workspace.isBusy)
            }
        }
    }

    private func prepareExport() {
        guard let root = workspace.workspaceURL else { return }
        workspace.isBusy = true
        Task {
            do {
                let output = FileManager.default.temporaryDirectory.appendingPathComponent("\(workspace.projectName).tendies")
                try? FileManager.default.removeItem(at: output)
                try await Task.detached(priority: .userInitiated) { try TendiesArchive.create(from: root, to: output) }.value
                let data = try Data(contentsOf: output)
                exportDocument = TendiesExportDocument(data: data)
                showingExporter = true
            } catch {
                workspace.errorMessage = error.localizedDescription
            }
            workspace.isBusy = false
        }
    }

    private var sidebar: some View {
        List(selection: $selectedTab) {
            Section("PROJECT") {
                Label("Workspace", systemImage: "square.grid.2x2").tag("Workspace")
                Label("Assets", systemImage: "photo.on.rectangle").tag("Assets")
                Label("Structure", systemImage: "list.bullet.indent").tag("Structure")
                Label("Validation", systemImage: "checkmark.shield").tag("Validation")
            }
            Section("TOOLS") {
                Label("Layer Editor", systemImage: "square.3.layers.3d").tag("Layers")
                Label("CAML Inspector", systemImage: "curlybraces").tag("CAML")
                Label("Metadata", systemImage: "doc.text.magnifyingglass").tag("Metadata")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Tendies Studio")
        .safeAreaInset(edge: .bottom) {
            HStack {
                Circle().fill(.green).frame(width: 7, height: 7)
                Text(workspace.status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
            }.padding()
        }
    }

    @ViewBuilder private var workspaceView: some View {
        if workspace.workspaceURL == nil {
            WelcomeView(openAction: { showingImporter = true })
        } else {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(workspace.projectName).font(.title2.bold())
                            Text("\(workspace.entries.count) package entries")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { workspace.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    }
                    Divider()
                    if selectedTab == "Assets" {
                        AssetBrowserView()
                    } else if selectedTab == "Structure" {
                        PackageBrowserView()
                    } else if selectedTab == "CAML" || selectedTab == "Metadata" {
                        InspectorPlaceholder(title: selectedTab, subtitle: "Select a file in the package browser to inspect its contents.")
                    } else if selectedTab == "Validation" {
                        ValidationView()
                    } else {
                        PackageOverviewView()
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

struct WelcomeView: View {
    let openAction: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 58, weight: .light)).foregroundStyle(.cyan)
            Text("Your wallpaper workspace").font(.largeTitle.bold())
            Text("Create, inspect and refine PosterBoard Tendies packages in a native iPad workspace.")
                .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 540)
            Button(action: openAction) {
                Label("Open a .tendies package", systemImage: "folder.badge.plus")
                    .font(.headline).padding(.horizontal, 24).padding(.vertical, 14)
            }.buttonStyle(.borderedProminent)
            Text("New projects from validated templates are coming next.")
                .font(.footnote).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}
