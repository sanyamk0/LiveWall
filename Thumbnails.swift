import AppKit
import AVFoundation
import SwiftUI

/// Generates (and caches in memory) a small preview frame for each video.
actor ThumbnailCache {
    static let shared = ThumbnailCache()
    private var cache: [URL: NSImage] = [:]

    func image(for url: URL) async -> NSImage? {
        if let cached = cache[url] { return cached }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)
        guard let cg = try? await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600)).image
        else { return nil }
        let image = NSImage(cgImage: cg, size: .zero)
        cache[url] = image
        return image
    }
}

struct ThumbnailView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .task(id: url) { image = await ThumbnailCache.shared.image(for: url) }
    }
}
