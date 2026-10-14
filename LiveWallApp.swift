import SwiftUI

// Entry point. The app lives only in the menu bar (no Dock icon, no main window).
@main
struct LiveWallApp: App {
    // AppDelegate owns the long-lived objects so they start at launch,
    // not only when you first open the menu bar panel.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("LiveWall", systemImage: "play.rectangle.on.rectangle") {
            MenuView()
                .environmentObject(appDelegate.library)
                .environmentObject(appDelegate.wallpaper)
        }
        .menuBarExtraStyle(.window) // a real SwiftUI panel instead of a plain menu
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let library = VideoLibrary()
    let wallpaper = WallpaperManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Restore the last wallpaper automatically (after quit, crash or reboot).
        if let current = library.current {
            wallpaper.setWallpaper(url: library.fileURL(for: current))
        }
    }
}
