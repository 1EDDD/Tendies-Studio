import Foundation
import UIKit

enum TendiesProjectFactory {
    static func create(
        at root: URL,
        name: String,
        size: CGSize,
        logicalScreenClass: String,
        imageData: Data?
    ) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let descriptorID = UUID().uuidString.uppercased()
        let wallpaperID = Int.random(in: 1000...9999)
        let safeName = sanitize(name.isEmpty ? "Custom Wallpaper" : name)
        let base = root.appendingPathComponent("descriptors").appendingPathComponent(descriptorID)
        let versions = base.appendingPathComponent("versions/1")
        let contents = versions.appendingPathComponent("contents")
        let wallpaper = contents.appendingPathComponent("\(wallpaperID).Custom-\(logicalScreenClass).wallpaper")

        try fm.createDirectory(at: wallpaper, withIntermediateDirectories: true)

        try "(wallpaperID)".data(using: .utf8)!.write(
            to: base.appendingPathComponent("com.apple.posterkit.provider.descriptor.identifier")
        )
        try "PRPosterRoleLockScreen".data(using: .utf8)!.write(
            to: base.appendingPathComponent("com.apple.posterkit.role.identifier")
        )

        try minimalPlist().write(to: base.appendingPathComponent("providerInfo.plist"), atomically: true, encoding: .utf8)
        try minimalPlist().write(to: versions.appendingPathComponent("com.apple.posterkit.provider.instance.complicationLayout.plist"), atomically: true, encoding: .utf8)
        try minimalPlist().write(to: versions.appendingPathComponent("com.apple.posterkit.provider.instance.titleStyleConfiguration.plist"), atomically: true, encoding: .utf8)
        try minimalPlist().write(to: versions.appendingPathComponent("RuntimeSnapshotMetadata-home.plist"), atomically: true, encoding: .utf8)
        try minimalPlist().write(to: versions.appendingPathComponent("RuntimeSnapshotMetadata-lock.plist"), atomically: true, encoding: .utf8)

        let userInfo = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
          <key>wallpaperRepresentingIdentifier</key><string>\(wallpaperID)</string>
          <key>wallpaperRepresentingFileName</key><string>\(wallpaper.lastPathComponent)</string>
          <key>posterEnvironmentOverrides</key><string>{}</string>
        </dict></plist>
        """
        try userInfo.write(to: contents.appendingPathComponent("com.apple.posterkit.provider.contents.userInfo"), atomically: true, encoding: .utf8)
        try minimalPlist().write(to: contents.appendingPathComponent(".com.apple.posterkit.provider.contents.configurableOptions.plist"), atomically: true, encoding: .utf8)
        try minimalPlist().write(to: contents.appendingPathComponent("com.apple.posterkit.provider.contents.otherMetadata.plist"), atomically: true, encoding: .utf8)

        let wallpaperPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
          <key>assets</key><dict>
            <key>lockAndHome</key><dict>
              <key>default</key><dict>
                <key>foregroundAnimationFileName</key><string>\(wallpaperID).Custom_Foreground-\(logicalScreenClass).ca</string>
                <key>backgroundAnimationFileName</key><string>\(wallpaperID).Custom_Background-\(logicalScreenClass).ca</string>
                <key>floatingAnimationFileNameKey</key><string>\(wallpaperID).Custom_Floating-\(logicalScreenClass).ca</string>
                <key>name</key><string>\(safeName)</string>
                <key>type</key><string>LayeredAnimation</string>
                <key>identifier</key><integer>\(wallpaperID)</integer>
              </dict>
            </dict>
          </dict>
          <key>family</key><string>Custom</string>
          <key>logicalScreenClass</key><string>\(logicalScreenClass)</string>
          <key>appearanceAware</key><false/>
          <key>identifier</key><integer>\(wallpaperID)</integer>
          <key>version</key><integer>1</integer>
          <key>name</key><string>\(safeName)</string>
        </dict></plist>
        """
        try wallpaperPlist.write(to: wallpaper.appendingPathComponent("Wallpaper.plist"), atomically: true, encoding: .utf8)

        try writeCA(
            name: "\(wallpaperID).Custom_Background-\(logicalScreenClass).ca",
            parent: wallpaper,
            width: size.width,
            height: size.height,
            imageData: imageData
        )
        try writeCA(
            name: "\(wallpaperID).Custom_Floating-\(logicalScreenClass).ca",
            parent: wallpaper,
            width: size.width,
            height: size.height,
            imageData: nil
        )
        try writeCA(
            name: "\(wallpaperID).Custom_Foreground-\(logicalScreenClass).ca",
            parent: wallpaper,
            width: size.width,
            height: size.height,
            imageData: nil
        )
    }

    private static func writeCA(
        name: String,
        parent: URL,
        width: CGFloat,
        height: CGFloat,
        imageData: Data?
    ) throws {
        let fm = FileManager.default
        let ca = parent.appendingPathComponent(name)
        let assets = ca.appendingPathComponent("assets")
        try fm.createDirectory(at: assets, withIntermediateDirectories: true)

        let hasImage = imageData != nil
        if let imageData {
            try imageData.write(to: assets.appendingPathComponent("Background.png"), options: .atomic)
        }

        let rootName = imageData == nil ? "_EMPTY" : "Background.png"
        let layerID = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        let imageLayer = hasImage
            ? """
              <CALayer id="\(layerID)" name="\(rootName)" bounds="0 0 \(Self.n(width)) \(Self.n(height))" position="\(Self.n(width / 2)) \(Self.n(height / 2))" zPosition="0" geometryFlipped="0" opacity="1" transform.rotation.z="0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <contents><CGImage src="assets/Background.png"/></contents>
              </CALayer>
              """
            : ""

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <caml xmlns="http://www.apple.com/CoreAnimation/1.0">
          <CALayer id="__capRootLayer__" name="Root Layer" bounds="0 0 \(Self.n(width)) \(Self.n(height))" position="\(Self.n(width / 2)) \(Self.n(height / 2))" geometryFlipped="0" opacity="1" contentsFormat="RGBA8">
            <sublayers>\(imageLayer)</sublayers>
            <modules/>
            <states>
              <LKState name="Locked"><elements/></LKState>
              <LKState name="Unlock"><elements/></LKState>
              <LKState name="Sleep"><elements/></LKState>
            </states>
          </CALayer>
        </caml>
        """

        try xml.write(to: ca.appendingPathComponent("main.caml"), atomically: true, encoding: .utf8)

        let index = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
          <key>assetManifest</key><string>assetManifest.caml</string>
          <key>documentHeight</key><real>\(Self.n(height))</real>
          <key>documentResizesToView</key><true/>
          <key>documentWidth</key><real>\(Self.n(width))</real>
          <key>dynamicGuidesEnabled</key><true/>
          <key>geometryFlipped</key><false/>
          <key>guidesEnabled</key><true/>
          <key>interactiveMouseEventsEnabled</key><true/>
          <key>interactiveTouchEventsEnabled</key><false/>
          <key>loopEnd</key><real>0.0</real>
          <key>loopStart</key><real>0.0</real>
          <key>loopingEnabled</key><false/>
          <key>rootDocument</key><string>main.caml</string>
          <key>scalesToFitInPlayer</key><true/>
          <key>snappingEnabled</key><true/>
          <key>unitsInPixelsInPlayer</key><true/>
        </dict></plist>
        """
        try index.write(to: ca.appendingPathComponent("index.xml"), atomically: true, encoding: .utf8)

        let manifest = """
        <?xml version="1.0" encoding="UTF-8"?>
        <caml xmlns="http://www.apple.com/CoreAnimation/1.0">
          <MicaAssetManifest><modules type="NSArray"/></MicaAssetManifest>
        </caml>
        """
        try manifest.write(to: ca.appendingPathComponent("assetManifest.caml"), atomically: true, encoding: .utf8)
    }

    private static func minimalPlist() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict/></plist>
        """
    }

    private static func sanitize(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func n(_ value: CGFloat) -> String {
        if abs(value.rounded() - value) < 0.000001 { return String(Int(value.rounded())) }
        return String(format: "%.4f", value)
    }
}
