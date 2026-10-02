import SwiftUI
import UIKit

struct StudioEditorView: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @State private var zoom: CGFloat = 0.58
    @State private var showAddImage = false
    @State private var showReplaceImage = false
    @State private var layerSearch = ""
    @State private var surfaceFilter: LayerSurface? = nil
    @State private var snapEnabled = true
    @State private var showGrid = true
    @State private var dragStart: StudioLayer?

    var filteredLayers: [StudioLayer] {
        workspace.layers.filter { layer in
            let surfaceMatches = surfaceFilter == nil || layer.surface == surfaceFilter
            let searchMatches = layerSearch.isEmpty ||
                layer.name.localizedCaseInsensitiveContains(layerSearch) ||
                layer.surface.rawValue.localizedCaseInsensitiveContains(layerSearch)
            return surfaceMatches && searchMatches
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider()

            HStack(spacing: 0) {
                LayersPanel(
                    layers: filteredLayers,
                    search: $layerSearch,
                    surfaceFilter: $surfaceFilter,
                    showAddImage: $showAddImage
                )
                .frame(minWidth: 258, idealWidth: 286, maxWidth: 320)

                Divider()

                CanvasWorkspace(
                    zoom: $zoom,
                    showGrid: $showGrid,
                    snapEnabled: $snapEnabled,
                    dragStart: $dragStart
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                InspectorWorkspace(showReplaceImage: $showReplaceImage)
                    .frame(minWidth: 300, idealWidth: 330, maxWidth: 360)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .sheet(isPresented: $showAddImage) {
            MediaImportSheet(title: "Add Image Layer") { data, name in
                workspace.addImageFromData(data, preferredName: name)
            }
        }
        .sheet(isPresented: $showReplaceImage) {
            MediaImportSheet(title: "Replace Image") { data, _ in
                guard let id = workspace.selectedLayerID else { return }
                workspace.replaceImage(for: id, with: data)
            }
        }
    }

    private var editorHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.projectName)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)

                Text("\(Int(workspace.projectSettings.width)) × \(Int(workspace.projectSettings.height))  •  \(workspace.layers.count) layers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                StatusChip(
                    icon: workspace.isBusy ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill",
                    title: workspace.isBusy ? "Working" : "Local"
                )

                Button { showAddImage = true } label: {
                    Label("Add Image", systemImage: "photo.badge.plus")
                }
                .buttonStyle(.bordered)

                Button { workspace.activePanel = .assets } label: {
                    Label("Assets", systemImage: "photo.stack")
                }
                .buttonStyle(.bordered)

                Button { workspace.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial)
    }
}

private struct StatusChip: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }
}

private struct LayersPanel: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    let layers: [StudioLayer]
    @Binding var search: String
    @Binding var surfaceFilter: LayerSurface?
    @Binding var showAddImage: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Layers")
                    .font(.title3.weight(.bold))
                Spacer()
                Button { showAddImage = true } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add image layer")
            }
            .padding(.horizontal, 16)
            .padding(.top, 15)
            .padding(.bottom, 10)

            TextField("Search layers", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    filterPill(title: "All", selected: surfaceFilter == nil) {
                        surfaceFilter = nil
                    }

                    ForEach(LayerSurface.allCases) { surface in
                        filterPill(
                            title: surface.rawValue,
                            selected: surfaceFilter == surface
                        ) {
                            surfaceFilter = surface
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            Divider()

            if layers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "square.stack.3d.down.right")
                        .font(.title2)
                        .foregroundStyle(.tertiary)

                    Text(search.isEmpty && surfaceFilter == nil ? "No layers yet" : "No matching layers")
                        .font(.subheadline.weight(.semibold))

                    Text("Add an image to start building the wallpaper.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(layers.reversed()) { layer in
                            LayerRow(layer: layer)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.70), .black.opacity(0.84)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func filterPill(
        title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(selected ? .primary : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(selected ? Color.cyan.opacity(0.17) : Color.white.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct LayerRow: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    let layer: StudioLayer

    var body: some View {
        Button {
            workspace.selectedLayerID = layer.id
        } label: {
            HStack(spacing: 10) {
                thumbnail

                VStack(alignment: .leading, spacing: 3) {
                    Text(layer.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(layer.surface.rawValue)
                        Text("•")
                        Text("\(Int(layer.width))×\(Int(layer.height))")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if layer.imageSource != nil {
                    Circle()
                        .fill(layer.hasValidImage ? .green : .orange)
                        .frame(width: 7, height: 7)
                }

                Image(systemName: layer.hidden ? "eye.slash" : "eye")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        layer.id == workspace.selectedLayerID
                            ? Color.cyan.opacity(0.13)
                            : Color.white.opacity(0.001)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        layer.id == workspace.selectedLayerID
                            ? Color.cyan.opacity(0.25)
                            : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private var thumbnail: some View {
        Group {
            if let path = layer.imageFilePath,
               let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.05))
                    Image(systemName: "square.3.layers.3d")
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

private struct CanvasWorkspace: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @Binding var zoom: CGFloat
    @Binding var showGrid: Bool
    @Binding var snapEnabled: Bool
    @Binding var dragStart: StudioLayer?

    var body: some View {
        VStack(spacing: 0) {
            canvasToolbar
            Divider()

            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    ZStack {
                        Color.clear
                            .frame(
                                minWidth: proxy.size.width,
                                minHeight: proxy.size.height
                            )

                        DeviceCanvas(
                            zoom: zoom,
                            showGrid: showGrid,
                            dragStart: $dragStart
                        )
                    }
                    .frame(
                        minWidth: max(proxy.size.width, workspace.projectSettings.width * zoom + 180),
                        minHeight: max(proxy.size.height, workspace.projectSettings.height * zoom + 180)
                    )
                }
            }

            Divider()
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: snapEnabled ? "scope" : "scope")
                    Text(snapEnabled ? "Snap" : "Free")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(zoom * 100))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(workspace.layers.count) layers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(.thinMaterial)
        }
        .background(Color.black.opacity(0.96))
    }

    private var canvasToolbar: some View {
        HStack(spacing: 7) {
            ToolButton(symbol: "cursorarrow", active: true)
            ToolButton(symbol: "hand.draw")
                .opacity(0.55)

            Divider().frame(height: 20)

            Button {
                showGrid.toggle()
            } label: {
                Image(systemName: showGrid ? "grid" : "grid.circle")
            }
            .buttonStyle(.borderless)
            .help("Toggle grid")

            Button {
                snapEnabled.toggle()
            } label: {
                Image(systemName: snapEnabled ? "scope" : "scope")
                    .foregroundStyle(snapEnabled ? .cyan : .secondary)
            }
            .buttonStyle(.borderless)

            Spacer()

            Button { zoom = max(0.2, zoom - 0.1) } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.borderless)

            Text("\(Int(zoom * 100))%")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 48)

            Button { zoom = min(2.0, zoom + 0.1) } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)

            Button { zoom = 0.58 } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.borderless)
            .help("Fit")
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
    }
}

private struct ToolButton: View {
    let symbol: String
    var active = false

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(active ? .primary : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(active ? .white.opacity(0.08) : .clear)
            )
    }
}

private struct DeviceCanvas: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    let zoom: CGFloat
    let showGrid: Bool
    @Binding var dragStart: StudioLayer?

    var body: some View {
        let size = workspace.projectSettings.size

        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(.white.opacity(0.07), lineWidth: 1)
                )
                .frame(
                    width: size.width * zoom + 94,
                    height: size.height * zoom + 94
                )

            ZStack {
                if showGrid {
                    GridBackground()
                }

                ForEach(workspace.layers.sorted { $0.zPosition < $1.zPosition }) { layer in
                    canvasLayer(layer)
                }

                if workspace.layers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 38))
                            .foregroundStyle(.tertiary)

                        Text("Your canvas is empty")
                            .font(.headline)

                        Text("Add an image layer to begin.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(alignment: .topLeading) {
                Text(workspace.projectSettings.target.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule())
                    .offset(x: 10, y: -10)
            }
            .shadow(color: .black.opacity(0.5), radius: 28, y: 17)
            .scaleEffect(zoom)
        }
        .frame(
            width: size.width * zoom + 94,
            height: size.height * zoom + 94
        )
    }

    @ViewBuilder
    private func canvasLayer(_ layer: StudioLayer) -> some View {
        let selected = workspace.selectedLayerID == layer.id

        ZStack {
            if let path = layer.imageFilePath,
               let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.cyan.opacity(0.06))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    )
            }

            if selected {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.cyan, lineWidth: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
            }
        }
        .frame(width: max(layer.width, 1), height: max(layer.height, 1))
        .rotationEffect(.radians(layer.rotation))
        .opacity(layer.hidden ? 0 : layer.opacity)
        .position(x: layer.x, y: layer.y)
        .contentShape(Rectangle())
        .onTapGesture {
            workspace.selectedLayerID = layer.id
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    guard selected else { return }
                    if dragStart == nil {
                        dragStart = layer
                    }

                    guard let start = dragStart,
                          let index = workspace.layers.firstIndex(where: { $0.id == start.id }) else { return }

                    var updated = start
                    updated.x = start.x + value.translation.width / zoom
                    updated.y = start.y + value.translation.height / zoom

                    if let snapped = snapValue(updated.x, to: workspace.projectSettings.width / 2) {
                        updated.x = snapped
                    }
                    if let snapped = snapValue(updated.y, to: workspace.projectSettings.height / 2) {
                        updated.y = snapped
                    }

                    workspace.layers[index] = updated
                }
                .onEnded { _ in
                    if let current = workspace.selectedLayer {
                        workspace.updateLayer(current)
                    }
                    dragStart = nil
                }
        )
    }

    private func snapValue(_ value: Double, to center: Double) -> Double? {
        let threshold = 8.0
        return abs(value - center) <= threshold ? center : nil
    }
}

private struct GridBackground: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 24
            for y in stride(from: CGFloat.zero, through: size.height, by: step) {
                for x in stride(from: CGFloat.zero, through: size.width, by: step) {
                    let row = Int(y / step)
                    let col = Int(x / step)
                    let rect = CGRect(x: x, y: y, width: step, height: step)
                    let isDark = (row + col).isMultiple(of: 2)
                    context.fill(
                        Path(rect),
                        with: .color(isDark ? .white.opacity(0.018) : .white.opacity(0.035))
                    )
                }
            }
        }
    }
}

private struct InspectorWorkspace: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @Binding var showReplaceImage: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Inspector")
                    .font(.title3.weight(.bold))
                Spacer()

                if workspace.selectedLayer != nil {
                    Button {
                        showReplaceImage = true
                    } label: {
                        Image(systemName: "photo.badge.arrow.down")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)

            Divider()

            if let layer = workspace.selectedLayer {
                ScrollView {
                    VStack(spacing: 12) {
                        InspectorIdentity(layer: layer)
                        TransformSection(layer: layer)
                        AppearanceSection(layer: layer)
                        AssetSection(layer: layer)
                    }
                    .padding(14)
                }
            } else {
                ContentUnavailableView(
                    "Nothing selected",
                    systemImage: "slider.horizontal.3",
                    description: Text("Choose a layer from the Layers panel or canvas.")
                )
                .padding()
            }
        }
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.03), Color.black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct InspectorIdentity: View {
    let layer: StudioLayer

    var body: some View {
        InspectorCard(title: "Layer") {
            HStack(spacing: 11) {
                if let path = layer.imageFilePath,
                   let image = UIImage(contentsOfFile: path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.05))
                        .frame(width: 54, height: 54)
                        .overlay(Image(systemName: "square.3.layers.3d"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(layer.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(layer.surface.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Circle()
                    .fill(layer.imageSource == nil ? .gray : (layer.hasValidImage ? .green : .orange))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

private struct TransformSection: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    let layer: StudioLayer

    var body: some View {
        InspectorCard(title: "Transform") {
            VStack(spacing: 9) {
                twoColumn("X", layer.x) { update { $0.x = $1 } }
                twoColumn("Y", layer.y) { update { $0.y = $1 } }
                twoColumn("Width", layer.width) { update { $0.width = max(1, $1) } }
                twoColumn("Height", layer.height) { update { $0.height = max(1, $1) } }
                twoColumn("Rotation", layer.rotation) { update { $0.rotation = $1 } }
                twoColumn("Z", layer.zPosition) { update { $0.zPosition = $1 } }
            }
        }
    }

    private func twoColumn(
        _ title: String,
        _ value: Double,
        _ change: @escaping (inout StudioLayer, Double) -> Void
    ) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            TextField(
                "",
                value: Binding(
                    get: { value },
                    set: { newValue in
                        update({ layerValue, value in
                            change(&layerValue, value)
                        }, value: newValue)
                    }
                ),
                format: .number
            )
            .frame(width: 90)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
        }
    }

    private func update(_ change: (inout StudioLayer, Double) -> Void, value: Double = 0) {
        guard var changed = workspace.selectedLayer else { return }
        change(&changed, value)
        workspace.updateLayer(changed)
    }
}

private struct AppearanceSection: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    let layer: StudioLayer

    var body: some View {
        InspectorCard(title: "Appearance") {
            VStack(spacing: 11) {
                Toggle(
                    "Visible",
                    isOn: Binding(
                        get: { !layer.hidden },
                        set: { visible in
                            apply { $0.hidden = !visible }
                        }
                    )
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Opacity").font(.subheadline)
                        Spacer()
                        Text("\(Int(layer.opacity * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { layer.opacity },
                            set: { value in apply { $0.opacity = value } }
                        ),
                        in: 0...1
                    )
                }
            }
        }
    }

    private func apply(_ change: (inout StudioLayer) -> Void) {
        var value = workspace.selectedLayer ?? layer
        change(&value)
        workspace.updateLayer(value)
    }
}

private struct AssetSection: View {
    let layer: StudioLayer

    var body: some View {
        if let source = layer.imageSource {
            InspectorCard(title: "Asset") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(layer.hasValidImage ? "Ready" : "Missing")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: layer.hasValidImage ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(layer.hasValidImage ? .green : .orange)
                    }

                    Text(source)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

private struct InspectorCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            content()
                .padding(12)
                .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 13))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(.white.opacity(0.055), lineWidth: 1)
                )
        }
    }
}
