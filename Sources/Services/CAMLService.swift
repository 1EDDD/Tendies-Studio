import Foundation

final class CAMLParser: NSObject, XMLParserDelegate {
    private(set) var layers: [StudioLayer] = []
    private var stack: [Int] = []
    private var currentRoot: URL = .temporaryDirectory
    private var currentCAMLPath = ""
    private var currentSurface: LayerSurface = .background
    private var insideContents = false

    func parse(data: Data, camlPath: String, surface: LayerSurface, caFolder: URL) -> [StudioLayer] {
        layers = []
        stack = []
        currentRoot = caFolder
        currentCAMLPath = camlPath
        currentSurface = surface
        insideContents = false

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false
        parser.parse()
        return layers
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        if elementName == "contents" {
            insideContents = true
            return
        }

        if elementName == "CGImage", insideContents, let src = attributeDict["src"], let index = stack.last {
            layers[index].imageSource = src
            return
        }

        if elementName != "CALayer" {
            return
        }

        let id = attributeDict["id"] ?? UUID().uuidString
        let name = attributeDict["name"] ?? "Layer"
        let bounds = Self.parsePairRect(attributeDict["bounds"])
        let position = Self.parsePair(attributeDict["position"])
        let width = bounds.width > 0 ? bounds.width : 100
        let height = bounds.height > 0 ? bounds.height : 100

        let layer = StudioLayer(
            id: id,
            name: name,
            surface: currentSurface,
            camlPath: currentCAMLPath,
            caFolderPath: currentRoot.path,
            imageSource: nil,
            x: position.x,
            y: position.y,
            width: width,
            height: height,
            rotation: Double(attributeDict["transform.rotation.z"] ?? "0") ?? 0,
            opacity: Double(attributeDict["opacity"] ?? "1") ?? 1,
            zPosition: Double(attributeDict["zPosition"] ?? "0") ?? 0,
            hidden: attributeDict["hidden"] == "1"
        )

        layers.append(layer)
        stack.append(layers.count - 1)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "contents" {
            insideContents = false
        } else if elementName == "CALayer", !stack.isEmpty {
            stack.removeLast()
        }
    }


    private static func parsePair(_ value: String?) -> (x: Double, y: Double) {
        guard let value else { return (0, 0) }
        let p = value.split(separator: " ").compactMap { Double($0) }
        guard p.count >= 2 else { return (0, 0) }
        return (p[0], p[1])
    }

    private static func parsePairRect(_ value: String?) -> (width: Double, height: Double) {
        guard let value else { return (100, 100) }
        let p = value.split(separator: " ").compactMap { Double($0) }
        guard p.count >= 4 else { return (100, 100) }
        return (p[2], p[3])
    }
}

enum CAMLService {
    static func discoverLayers(in workspace: URL) throws -> [StudioLayer] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: workspace,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var result: [StudioLayer] = []

        while let url = enumerator.nextObject() as? URL {
            guard url.lastPathComponent == "main.caml" else { continue }

            let components = url.pathComponents.map { $0.lowercased() }
            let surface: LayerSurface
            if components.contains(where: { $0.contains("foreground") }) {
                surface = .foreground
            } else if components.contains(where: { $0.contains("floating") }) {
                surface = .floating
            } else {
                surface = .background
            }

            let data = try Data(contentsOf: url)
            let relative = String(url.path.dropFirst(workspace.path.count + 1))
            let parsed = CAMLParser().parse(
                data: data,
                camlPath: relative,
                surface: surface,
                caFolder: url.deletingLastPathComponent()
            )
            result.append(contentsOf: parsed.filter {
                $0.id != "__capRootLayer__" &&
                !$0.name.localizedCaseInsensitiveContains("root layer")
            })
        }

        return result.sorted {
            if $0.surface != $1.surface {
                return $0.surface.rawValue < $1.surface.rawValue
            }
            if $0.zPosition != $1.zPosition {
                return $0.zPosition < $1.zPosition
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    static func writeLayer(_ layer: StudioLayer, in workspace: URL) throws {
        guard !layer.camlPath.isEmpty else { return }
        let file = workspace.appendingPathComponent(layer.camlPath)
        var text = try String(contentsOf: file, encoding: .utf8)

        let escaped = NSRegularExpression.escapedPattern(for: layer.id)
        let pattern = "<CALayer\\b[^>]*\\bid="\(escaped)"[^>]*>"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return }

        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = re.firstMatch(in: text, range: range) else { return }

        var tag = ns.substring(with: match.range)
        tag = replaceAttribute("bounds", value: "0 0 \(Self.n(layer.width)) \(Self.n(layer.height))", in: tag)
        tag = replaceAttribute("position", value: "\(Self.n(layer.x)) \(Self.n(layer.y))", in: tag)
        tag = replaceAttribute("transform.rotation.z", value: Self.n(layer.rotation), in: tag)
        tag = replaceAttribute("opacity", value: Self.n(layer.opacity), in: tag)
        tag = replaceAttribute("zPosition", value: Self.n(layer.zPosition), in: tag)
        tag = replaceAttribute("hidden", value: layer.hidden ? "1" : "0", in: tag)

        text = ns.replacingCharacters(in: match.range, with: tag)
        text = replaceImageSource(text, layerID: layer.id, source: layer.imageSource)
        try text.write(to: file, atomically: true, encoding: .utf8)
    }

    static func readText(relativePath: String, in workspace: URL) throws -> String {
        try String(contentsOf: workspace.appendingPathComponent(relativePath), encoding: .utf8)
    }

    static func writeText(_ text: String, relativePath: String, in workspace: URL) throws {
        try text.write(to: workspace.appendingPathComponent(relativePath), atomically: true, encoding: .utf8)
    }

    private static func replaceAttribute(_ name: String, value: String, in tag: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        guard let re = try? NSRegularExpression(pattern: "\\b\(escaped)="[^"]*"") else {
            return tag
        }
        return re.stringByReplacingMatches(
            in: tag,
            range: NSRange(location: 0, length: (tag as NSString).length),
            withTemplate: "\(name)="\(value)""
        )
    }

    private static func replaceImageSource(_ text: String, layerID: String, source: String?) -> String {
        guard let source else { return text }
        let escaped = NSRegularExpression.escapedPattern(for: layerID)
        let pattern = "(<CALayer\\b[^>]*\\bid="\(escaped)"[\\s\\S]*?<contents>[\\s\\S]*?<CGImage\\s+src=")[^"]+("\\s*/>[\\s\\S]*?</contents>)"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
        let replacement = "$1\(source)$2"
        return re.stringByReplacingMatches(
            in: text,
            range: NSRange(location: 0, length: (text as NSString).length),
            withTemplate: replacement
        )
    }

    private static func n(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.000001 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.4f", value)
    }
}
