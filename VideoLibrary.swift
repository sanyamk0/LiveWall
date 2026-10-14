import Foundation
import Combine

struct Wallpaper: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let fileName: String
    let addedAt: Date
}

/// Stores imported videos in the app's own folder so they survive restarts,
/// and remembers which one is the current wallpaper.
@MainActor
final class VideoLibrary: ObservableObject {
    @Published private(set) var items: [Wallpaper] = []
    @Published var currentID: UUID? {
        didSet { UserDefaults.standard.set(currentID?.uuidString, forKey: "currentWallpaperID") }
    }

    var current: Wallpaper? { items.first { $0.id == currentID } }

    // Inside the sandbox this is ~/Library/Containers/<bundle id>/Data/Library/Application Support/LiveWall
    private let baseFolder: URL
    private let videosFolder: URL
    private var indexFile: URL { baseFolder.appendingPathComponent("library.json") }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseFolder = support.appendingPathComponent("LiveWall", isDirectory: true)
        videosFolder = baseFolder.appendingPathComponent("Videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: videosFolder, withIntermediateDirectories: true)
        load()
        if let saved = UserDefaults.standard.string(forKey: "currentWallpaperID"),
           let id = UUID(uuidString: saved), items.contains(where: { $0.id == id }) {
            currentID = id
        }
    }

    func fileURL(for item: Wallpaper) -> URL {
        videosFolder.appendingPathComponent(item.fileName)
    }

    /// Copies picked files into the library. Copying runs off the main thread
    /// because 4K files can be several GB.
    func importVideos(_ urls: [URL]) async -> [Wallpaper] {
        let folder = videosFolder
        let imported: [Wallpaper] = await Task.detached(priority: .userInitiated) {
            var result: [Wallpaper] = []
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let id = UUID()
                let fileName = "\(id.uuidString).\(url.pathExtension.lowercased())"
                do {
                    try FileManager.default.copyItem(at: url, to: folder.appendingPathComponent(fileName))
                    result.append(Wallpaper(id: id,
                                            name: url.deletingPathExtension().lastPathComponent,
                                            fileName: fileName,
                                            addedAt: Date()))
                } catch {
                    print("Import failed for \(url.lastPathComponent): \(error)")
                }
            }
            return result
        }.value
        items.append(contentsOf: imported)
        save()
        return imported
    }

    func delete(_ item: Wallpaper) {
        try? FileManager.default.removeItem(at: fileURL(for: item))
        items.removeAll { $0.id == item.id }
        if currentID == item.id { currentID = nil }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexFile),
              let decoded = try? JSONDecoder().decode([Wallpaper].self, from: data) else { return }
        // Drop entries whose file went missing.
        items = decoded.filter { FileManager.default.fileExists(atPath: fileURL(for: $0).path) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: indexFile, options: .atomic)
    }
}
