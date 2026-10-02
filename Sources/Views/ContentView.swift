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
            .navigationSplitViewColumnWidth(min: 104, ideal: 112, max: 130)
        } detail: {
            VStack(spacing: 0) {
                studioCommandBar
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
            .background(
                LinearGradient(
                    colors: [Color.black, Color(red: 0.025, green: 0.035, blue: 0.045)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var studioCommandBar: some View {
        HStack(spacing: 12) {
            Button { showingNew = true } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("New project")

            Button { showingOpen = true } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Open package")

            Divider().frame(height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(workspace.projectName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text("\(Int(workspace.projectSettings.width)) × \(Int(workspace.projectSettings.height))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(workspace.isBusy ? .orange : .green)
                    .frame(width: 7, height: 7)
                Text(workspace.isBusy ? "Working" : "Saved locally")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.05), in: Capsule())

            Button {
                exportCurrentProject()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(workspace.isBusy)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
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
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.24), .blue.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.title3)
                        .foregroundStyle(.cyan)
                }

                Text("Tendies")
                    .font(.caption.weight(.bold))

                Text("STUDIO")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 15)
            .padding(.bottom, 16)

            Divider()

            VStack(spacing: 8) {
                sideItem(.design)
                sideItem(.assets)
                sideItem(.package)
                sideItem(.validation)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 8)

            Spacer()

            VStack(spacing: 8) {
                quickButton(systemImage: "plus", action: newAction)
                quickButton(systemImage: "folder", action: openAction)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.035, green: 0.04, blue: 0.045), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func sideItem(_ panel: StudioPanel) -> some View {
        Button {
            workspace.activePanel = panel
        } label: {
            VStack(spacing: 6) {
                Image(systemName: panel.symbol)
                    .font(.title3)
                Text(panel.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(workspace.activePanel == panel ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(workspace.activePanel == panel ? .cyan.opacity(0.14) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(workspace.activePanel == panel ? .cyan.opacity(0.25) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func quickButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 42, height: 34)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct WelcomeStudioView: View {
    let openAction: () -> Void
    let newAction: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color(red: 0.018, green: 0.06, blue: 0.07), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(.cyan.opacity(0.10))
                        .frame(width: 130, height: 130)
                        .blur(radius: 3)

                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(.cyan)
                }

                VStack(spacing: 9) {
                    Text("Tendies Studio")
                        .font(.system(size: 42, weight: .bold, design: .rounded))

                    Text("Design layered wallpaper packages with a real canvas, layers, assets and CAML controls.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 720)
                }

                HStack(spacing: 12) {
                    Button(action: newAction) {
                        Label("Create New", systemImage: "plus")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: openAction) {
                        Label("Open Package", systemImage: "folder")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 10) {
                    WelcomePill(icon: "rectangle.3.group.fill", text: "Canvas + Layers")
                    WelcomePill(icon: "photo.stack", text: "Photos + Files")
                    WelcomePill(icon: "curlybraces", text: "CAML Inspector")
                    WelcomePill(icon: "checkmark.shield.fill", text: "Validation")
                }
                .padding(.top, 8)
            }
            .padding(40)
        }
    }
}

struct WelcomePill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.05), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.06), lineWidth: 1))
    }
}
