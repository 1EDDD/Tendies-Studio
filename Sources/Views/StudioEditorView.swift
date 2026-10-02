import SwiftUI
import UIKit

struct StudioEditorView: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @State private var zoom: CGFloat = 0.62
    @State private var showAddImage = false
    @State private var showReplaceImage = false
    @State private var dragStart: StudioLayer?

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                StudioLayerList(showAddImage: $showAddImage)
                    .frame(width: min(285, proxy.size.width * 0.22))
                Divider()
                VStack(spacing: 0) {
                    HStack {
                        Label(workspace.projectName, systemImage: "wand.and.stars")
                            .font(.headline)
                        Spacer()
                        Picker("Zoom", selection: $zoom) {
                            Text("25%").tag(CGFloat(0.25))
                            Text("50%").tag(CGFloat(0.50))
                            Text("62%").tag(CGFloat(0.62))
                            Text("75%").tag(CGFloat(0.75))
                            Text("100%").tag(CGFloat(1.0))
                        }
                        .pickerStyle(.menu)
                        Button { showAddImage = true } label: {
                            Label("Add Layer", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(14)
                    .background(.thinMaterial)
                    Divider()

                    ScrollView([.horizontal, .vertical]) {
                        EditorCanvasView(zoom: zoom, dragStart: $dragStart)
                            .padding(50)
                    }
                    .background(Color.black.opacity(0.95))

                    Divider()
                    HStack {
                        Image(systemName: "play.fill")
                        Text("00:00").font(.system(.caption, design: .monospaced))
                        Spacer()
                        Text("\(workspace.layers.count) layers")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.thinMaterial)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                StudioInspector(showReplaceImage: $showReplaceImage)
                    .frame(width: min(325, proxy.size.width * 0.25))
            }
        }
        .sheet(isPresented: $showAddImage) {
            MediaImportSheet(title: "Add Image Layer") { data, name in
                workspace.addImageFromData(data, preferredName: name)
            }
        }
        .sheet(isPresented: $showReplaceImage) {
            if let id = workspace.selectedLayerID {
                MediaImportSheet(title: "Replace Image") { data, _ in
                    workspace.replaceImage(for: id, with: data)
                }
            }
        }
    }
}

struct StudioLayerList: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @Binding var showAddImage: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Layers").font(.headline)
                Spacer()
                Button { showAddImage = true } label: { Image(systemName: "plus") }
                    .buttonStyle(.borderless)
            }
            .padding(16)
            Divider()
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(LayerSurface.allCases) { surface in
                        let items = workspace.layers.filter { $0.surface == surface }
                        if !items.isEmpty {
                            Text(surface.rawValue.uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                            ForEach(items.reversed()) { layer in
                                StudioLayerRow(layer: layer)
                            }
                        }
                    }
                }
            }
        }
        .background(.thinMaterial)
    }
}

struct StudioLayerRow: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    let layer: StudioLayer

    var body: some View {
        Button {
            workspace.selectedLayerID = layer.id
        } label: {
            HStack(spacing: 10) {
                if let path = layer.imageFilePath,
                   let image = UIImage(contentsOfFile: path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.05))
                        .frame(width: 42, height: 42)
                        .overlay(Image(systemName: "square.3.layers.3d"))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(layer.name).lineLimit(1)
                    Text("\(Int(layer.width)) × \(Int(layer.height))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: layer.hidden ? "eye.slash" : "eye")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(layer.id == workspace.selectedLayerID ? Color.accentColor.opacity(0.16) : .clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 7)
    }
}

struct EditorCanvasView: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    let zoom: CGFloat
    @Binding var dragStart: StudioLayer?

    var body: some View {
        let size = workspace.projectSettings.size

        ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(.white.opacity(0.03))
            ZStack {
                checkerboard
                ForEach(workspace.layers.sorted { $0.zPosition < $1.zPosition }) { layer in
                    layerView(layer)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.4), radius: 28, y: 18)
            .scaleEffect(zoom)
        }
        .frame(width: size.width * zoom + 100, height: size.height * zoom + 100)
    }

    @ViewBuilder
    private func layerView(_ layer: StudioLayer) -> some View {
        let selected = layer.id == workspace.selectedLayerID

        ZStack {
            if let path = layer.imageFilePath,
               let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor.opacity(0.08))
                    .overlay(Text(layer.name).font(.caption2))
            }

            if selected {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .frame(width: max(1, layer.width), height: max(1, layer.height))
        .rotationEffect(.radians(layer.rotation))
        .opacity(layer.hidden ? 0 : layer.opacity)
        .position(x: layer.x, y: layer.y)
        .onTapGesture { workspace.selectedLayerID = layer.id }
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard selected else { return }
                    if dragStart == nil { dragStart = layer }
                    guard let start = dragStart,
                          let index = workspace.layers.firstIndex(where: { $0.id == start.id }) else { return }
                    var updated = start
                    updated.x += value.translation.width / zoom
                    updated.y += value.translation.height / zoom
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

    private var checkerboard: some View {
        Canvas { context, size in
            let tile: CGFloat = 24
            for row in 0...Int(size.height / tile) {
                for column in 0...Int(size.width / tile) {
                    let rect = CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile)
                    let dark = (row + column).isMultiple(of: 2)
                    context.fill(Path(rect), with: .color(dark ? .white.opacity(0.02) : .white.opacity(0.04)))
                }
            }
        }
    }
}

struct StudioInspector: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @Binding var showReplaceImage: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Inspector").font(.headline)
                Spacer()
                if workspace.selectedLayer != nil {
                    Button { showReplaceImage = true } label: {
                        Image(systemName: "photo.badge.arrow.down")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(16)
            Divider()

            ScrollView {
                if let layer = workspace.selectedLayer {
                    VStack(alignment: .leading, spacing: 18) {
                        GroupBox("Layer") {
                            VStack(alignment: .leading, spacing: 9) {
                                Text(layer.name).font(.headline)
                                Text(layer.surface.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Toggle(
                                    "Visible",
                                    isOn: Binding(
                                        get: { !layer.hidden },
                                        set: { newValue in update(layer) { $0.hidden = !newValue } }
                                    )
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        GroupBox("Transform") {
                            VStack(spacing: 10) {
                                field("X", layer.x) { value in update(layer) { $0.x = value } }
                                field("Y", layer.y) { value in update(layer) { $0.y = value } }
                                field("Width", layer.width) { value in update(layer) { $0.width = max(1, value) } }
                                field("Height", layer.height) { value in update(layer) { $0.height = max(1, value) } }
                                field("Rotation", layer.rotation) { value in update(layer) { $0.rotation = value } }
                                field("Z", layer.zPosition) { value in update(layer) { $0.zPosition = value } }
                            }
                        }

                        GroupBox("Appearance") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Opacity")
                                    Spacer()
                                    Text("\(Int(layer.opacity * 100))%")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(
                                    value: Binding(
                                        get: { layer.opacity },
                                        set: { update(layer) { $0.opacity = $1 } }
                                    ),
                                    in: 0...1
                                )
                            }
                        }

                        if let source = layer.imageSource {
                            GroupBox("Asset") {
                                Text(source)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding(16)
                } else {
                    ContentUnavailableView(
                        "Select a layer",
                        systemImage: "slider.horizontal.3",
                        description: Text("Choose a layer to edit its transform and appearance.")
                    )
                    .padding()
                }
            }
        }
        .background(.thinMaterial)
    }

    private func field(_ title: String, _ value: Double, change: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", value: Binding(get: { value }, set: change), format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 95)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func update(_ source: StudioLayer, change: (inout StudioLayer) -> Void) {
        var value = source
        change(&value)
        workspace.updateLayer(value)
    }
}
