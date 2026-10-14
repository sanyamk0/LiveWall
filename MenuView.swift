import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

/// The panel that opens from the menu bar icon.
struct MenuView: View {
    @EnvironmentObject private var library: VideoLibrary
    @EnvironmentObject private var wallpaper: WallpaperManager

    @State private var isImporting = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            libraryGrid
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LiveWall").font(.headline)
                Text(library.current.map { "Now playing: \($0.name)" } ?? "No wallpaper selected")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button { wallpaper.togglePlayPause() } label: {
                Image(systemName: wallpaper.isPlaying ? "pause.fill" : "play.fill").frame(width: 18)
            }
            .help(wallpaper.isPlaying ? "Pause" : "Play")
            .disabled(library.current == nil)

            Button { wallpaper.isMuted.toggle() } label: {
                Image(systemName: wallpaper.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill").frame(width: 18)
            }
            .help(wallpaper.isMuted ? "Unmute" : "Mute")
        }
    }

    @ViewBuilder
    private var libraryGrid: some View {
        if library.items.isEmpty {
            Text("No videos yet. Click “Add Videos…” to import .mp4 or .mov files.")
                .font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 80)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(library.items) { item in
                        WallpaperCell(item: item,
                                      url: library.fileURL(for: item),
                                      isCurrent: item.id == library.currentID,
                                      onSelect: { select(item) },
                                      onDelete: { delete(item) })
                    }
                }
            }
            .frame(height: 260)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Add Videos…", action: addVideos).disabled(isImporting)
                if isImporting { ProgressView().controlSize(.small) }
                Spacer()
                Button("Stop Wallpaper") {
                    wallpaper.stop()
                    library.currentID = nil
                }
                .disabled(library.current == nil)
            }
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        print("Launch at login failed: \(error)")
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            Button("Quit LiveWall") { NSApp.terminate(nil) }
        }
    }

    // MARK: Actions

    private func select(_ item: Wallpaper) {
        library.currentID = item.id
        wallpaper.setWallpaper(url: library.fileURL(for: item))
    }

    private func delete(_ item: Wallpaper) {
        if item.id == library.currentID { wallpaper.stop() }
        library.delete(item)
    }

    private func addVideos() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie, .movie]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true) // bring the panel in front
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        isImporting = true
        Task {
            let added = await library.importVideos(urls)
            isImporting = false
            // First video ever? Use it right away.
            if library.current == nil, let first = added.first { select(first) }
        }
    }
}

private struct WallpaperCell: View {
    let item: Wallpaper
    let url: URL
    let isCurrent: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            ThumbnailView(url: url)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(isCurrent ? Color.accentColor : .clear, lineWidth: 2))
                .overlay(alignment: .topTrailing) {
                    if hovering {
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .padding(3)
                        .help("Delete from library")
                    }
                }
            Text(item.name).font(.caption2).lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Set as Wallpaper", action: onSelect)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
