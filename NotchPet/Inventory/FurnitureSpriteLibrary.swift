import AppKit
import CoreGraphics
import Foundation
import SwiftUI
import os.log

/// Spritesheet loader for `furniture.png` + `furniture.json`. Mirrors
/// `PetSpriteLibrary` but holds one CGImage per tag (each furniture
/// item is a single-frame sprite).
@MainActor
final class FurnitureSpriteLibrary {
    static let shared = FurnitureSpriteLibrary()

    private let byId: [String: CGImage]

    private static let fallback: CGImage = {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil,
            width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return ctx.makeImage()!
    }()

    private init() {
        self.byId = Self.load()
    }

    private static func load() -> [String: CGImage] {
        let log = OSLog(subsystem: "com.notchpet.NotchPet", category: "Furniture")
        guard
            let pngURL = Bundle.main.url(
                forResource: "furniture", withExtension: "png", subdirectory: "Sprites"
            ),
            let jsonURL = Bundle.main.url(
                forResource: "furniture", withExtension: "json", subdirectory: "Sprites"
            )
        else {
            os_log(.error, log: log, "Furniture: sheet assets not found")
            return [:]
        }
        guard
            let nsImage = NSImage(contentsOf: pngURL),
            let sheet = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            os_log(.error, log: log, "Furniture: failed to decode %{public}@", pngURL.path)
            return [:]
        }

        let jsonData: Data
        do { jsonData = try Data(contentsOf: jsonURL) }
        catch {
            os_log(.error, log: log, "Furniture: failed to read json")
            return [:]
        }

        let decoded: FurnitureSheet
        do { decoded = try JSONDecoder().decode(FurnitureSheet.self, from: jsonData) }
        catch {
            os_log(.error, log: log, "Furniture: failed to decode json")
            return [:]
        }

        // Slice each source frame into a CGImage, then map each tag to
        // its first frame (single-frame per item).
        var sliced: [CGImage] = []
        for entry in decoded.frames {
            let r = entry.frame
            let rect = CGRect(x: r.x, y: r.y, width: r.w, height: r.h)
            sliced.append(sheet.cropping(to: rect) ?? fallback)
        }

        var byId: [String: CGImage] = [:]
        for tag in decoded.meta.frameTags {
            guard tag.from >= 0, tag.from < sliced.count else { continue }
            byId[tag.name] = sliced[tag.from]
        }
        os_log(.info, log: log, "Furniture: loaded %d items", byId.count)
        return byId
    }

    func image(for id: String) -> CGImage {
        byId[id] ?? Self.fallback
    }
}

// MARK: - Aseprite JSON schema (furniture-specific duplicate of PetSprite)

private struct FurnitureRect: Decodable { let x, y, w, h: Int }
private struct FurnitureFrameEntry: Decodable { let frame: FurnitureRect; let duration: Int }
private struct FurnitureTag: Decodable { let name: String; let from: Int; let to: Int }
private struct FurnitureMeta: Decodable { let frameTags: [FurnitureTag] }
private struct FurnitureSheet: Decodable {
    let frames: [FurnitureFrameEntry]
    let meta: FurnitureMeta
}

// MARK: - SwiftUI wrapper

/// Renders a single furniture item by id. 16×16 base with nearest-
/// neighbor scaling so pixel edges stay crisp at any display size.
struct FurnitureSpriteView: View {
    let id: String
    let size: CGFloat

    var body: some View {
        Image(decorative: FurnitureSpriteLibrary.shared.image(for: id), scale: 1.0)
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
