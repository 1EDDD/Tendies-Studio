import Foundation
import CoreGraphics

enum WallpaperTarget: String, CaseIterable, Identifiable {
    case iPhonePortrait
    case iPadPortrait
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iPhonePortrait: return "iPhone Portrait"
        case .iPadPortrait: return "iPad Portrait"
        case .custom: return "Custom"
        }
    }

    var size: CGSize {
        switch self {
        case .iPhonePortrait: return CGSize(width: 390, height: 844)
        case .iPadPortrait: return CGSize(width: 810, height: 1080)
        case .custom: return CGSize(width: 810, height: 1080)
        }
    }

    var logicalScreenClass: String {
        switch self {
        case .iPhonePortrait: return "390w-844h@3x~iphone"
        case .iPadPortrait: return "810w-1080h@2x~~ipad"
        case .custom: return "custom"
        }
    }
}

enum LayerSurface: String, CaseIterable, Identifiable {
    case background = "Background"
    case floating = "Floating"
    case foreground = "Foreground"

    var id: String { rawValue }
}

struct StudioLayer: Identifiable, Hashable {
    let id: String
    var name: String
    var surface: LayerSurface
    var camlPath: String
    var caFolderPath: String
    var imageSource: String?
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var rotation: Double
    var opacity: Double
    var zPosition: Double
    var hidden: Bool

    var imageFilePath: String? {
        guard let imageSource, !imageSource.isEmpty else { return nil }
        return caFolderPath + "/" + imageSource
    }

    static let empty = StudioLayer(
        id: UUID().uuidString,
        name: "Layer",
        surface: .background,
        camlPath: "",
        caFolderPath: "",
        imageSource: nil,
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        rotation: 0,
        opacity: 1,
        zPosition: 0,
        hidden: false
    )
}

struct StudioProjectSettings: Equatable {
    var name: String
    var target: WallpaperTarget
    var width: Double
    var height: Double

    var size: CGSize { CGSize(width: width, height: height) }
}

enum StudioPanel: String, CaseIterable, Identifiable {
    case design
    case assets
    case package
    case validation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .design: return "Design"
        case .assets: return "Assets"
        case .package: return "Package"
        case .validation: return "Validate"
        }
    }

    var symbol: String {
        switch self {
        case .design: return "rectangle.3.group"
        case .assets: return "photo.on.rectangle"
        case .package: return "shippingbox"
        case .validation: return "checkmark.shield"
        }
    }
}
