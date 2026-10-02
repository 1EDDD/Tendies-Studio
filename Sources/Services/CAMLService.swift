import Foundation

final class CAMLParser: NSObject, XMLParserDelegate {
    private(set) var layers: [StudioLayer] = []
    private var stack: [Int] = []
    private var currentCAMLPath = ""
    private var currentSurface: LayerSurface = .background
    private var currentCAFolder: URL = .temporaryDirectory
    private var insideContents = false

    func parse(data: Data, camlPath: String, surface: LayerSurface, caFolder: URL) -> [StudioLayer] {
        layers = []
        stack = []
        currentCAMLPath = camlPath
        currentSurface = surface
        currentCAFolder = caFolder
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

        if elementName == "CGImage", insideContents,
           let src = attributeDict["src"],
           let index = stack.last {
            layers[index].imageSource = src
            return
        }

        guard elementName == "CALayer" else { return }

        let id = attributeDict["id"] ?? UUID().uuidString
        let name = attributeDict["name"] ?? "Layer"
        let bounds = Self.parseRect(attributeDict["bounds"])
        let position = Self.parsePair(attributeDict["position"])

        let layer = StudioLayer(
            id: id,
            name: name,
            surface: currentSurface,
            camlPath: currentCAMLPath,
            caFolderPath: currentCAFolder.path,
            imageSource: nil,
            x: position.x,
            y: position.y,
            width: max(bounds.width, 1),
            height: max(bounds.height, 1),
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
        let values = value.split(separator: " ").compactMap { Double($0) }
        guard values.count >= 2 else { return (0, 0) }
        return (values[0], values[1])
    }

    private static func parseRect(_ value: String?) -> (width: Double, height: Double) {
        guard let value else { return (100, 100) }
        let values = value.split(separator: " ").compactMap { Double($0) }
        guard values.count >= 4 else { return (100, 100) }
        return (values[2], values[3])
    }
}

enum CAMLService {
    static func discoverLayers(in workspace: URL) throws -> [StudioLayer] {
        guard let enumerator = FileManager.default.enumerator(
            at: workspace,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return [] }

        var result: [StudioLayer] = []

        while let url = enumerator.nextObject() as? URL {
            guard url.lastPathComponent == "main.caml" else { continue }

            let lower = url.path.lowercased()
            let surface: LayerSurface
            if lower.contains("foreground") {
                surface = .foreground
            } else if lower.contains("floating") {
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
            if $0.surface.rawValue != $1.surface.rawValue {
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
        let text = try String(contentsOf: file, encoding: .utf8)
        let escaped = NSRegularExpression.escapedPattern(for: layer.id)
        let pattern = "<CALayer\\b[^>]*\\bid=\"" + escaped + "\"[^>]*>"

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let nsText = text as NSString
        let all = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, range: all) else { return }

        var tag = nsText.substring(with: match.range)
        tag = replaceAttribute("bounds", value: "0 0 " + n(layer.width) + " " + n(layer.height), in: tag)
        tag = replaceAttribute("position", value: n(layer.x) + " " + n(layer.y), in: tag)
        tag = replaceAttribute("transform.rotation.z", value: n(layer.rotation), in: tag)
        tag = replaceAttribute("opacity", value: n(layer.opacity), in: tag)
        tag = replaceAttribute("zPosition", value: n(layer.zPosition), in: tag)
        tag = replaceAttribute("hidden", value: layer.hidden ? "1" : "0", in: tag)

        var updated = nsText.replacingCharacters(in: match.range, with: tag)

        try updated.write(to: file, atomically: true, encoding: .utf8)
    }

    static func readText(relativePath: String, in workspace: URL) throws -> String {
        try String(contentsOf: workspace.appendingPathComponent(relativePath), encoding: .utf8)
    }

    static func writeText(_ text: String, relativePath: String, in workspace: URL) throws {
        try text.write(to: workspace.appendingPathComponent(relativePath), atomically: true, encoding: .utf8)
    }

    private static func replaceAttribute(_ name: String, value: String, in tag: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let pattern = "\\b" + escaped + "=\"[^\"]*\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return tag }

        let replacement = name + "=\"" + value + "\""
        return regex.stringByReplacingMatches(
            in: tag,
            range: NSRange(location: 0, length: (tag as NSString).length),
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
