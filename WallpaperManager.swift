import Foundation
import AppKit
import AVFoundation
import Combine


/// Shows one borderless window per screen at desktop level and plays a looping video in it.
@MainActor
final class WallpaperManager: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published var isMuted: Bool {
        didSet {
            player.isMuted = isMuted
            UserDefaults.standard.set(isMuted, forKey: "isMuted")
        }
    }

    // One player shared by every screen's layer, so all screens stay in sync
    // and the video is decoded only once.
    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var windows: [NSWindow] = []

    /// What the USER wants. macOS sometimes pauses the player on its own
    /// (Space switch, sleep, display off); we use this to undo that.
    private var wantsPlayback = false

    private var activity: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var tokens: [NSObjectProtocol] = []

    init() {
        isMuted = UserDefaults.standard.object(forKey: "isMuted") as? Bool ?? true
        player.isMuted = isMuted
        player.preventsDisplaySleepDuringVideoPlayback = false // let the Mac sleep normally
        player.automaticallyWaitsToMinimizeStalling = false     // local files, start instantly

        // Opt out of App Nap: otherwise macOS throttles a background app
        // whose windows are covered, which freezes the video.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Playing live wallpaper"
        )

        // If anything pauses the player behind our back, resume it.
        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.enforcePlaybackState() }
        }

        // Screens plugged in/out or resolution changed -> rebuild windows.
        tokens.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rebuildWindows() }
        })

        // Events after which macOS may have paused us.
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didWakeNotification,
                     NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            tokens.append(ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.enforcePlaybackState() }
            })
        }
    }

    // MARK: - Public controls

    func setWallpaper(url: URL) {
        looper?.disableLooping()
        player.removeAllItems()
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        if windows.isEmpty { rebuildWindows() }
        resume()
    }

    func togglePlayPause() { wantsPlayback ? pause() : resume() }

    func pause() {
        wantsPlayback = false
        player.pause()
        isPlaying = false
    }

    func resume() {
        guard looper != nil else { return }
        wantsPlayback = true
        player.play()
        isPlaying = true
    }

    /// Removes the live wallpaper; your normal macOS wallpaper shows again.
    func stop() {
        pause()
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    // MARK: - Internals

    private func enforcePlaybackState() {
        if wantsPlayback && player.timeControlStatus == .paused {
            player.play()
        }
        isPlaying = wantsPlayback
    }

    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        guard looper != nil else { return }

        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                                  backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: true)
            // Sit exactly at the desktop layer: above the system wallpaper, below icons.
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
            // THE fix for "stops when I switch screens": be present on every Space
            // and don't move or animate during Space switches / Mission Control.
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.ignoresMouseEvents = true
            window.isOpaque = true
            window.hasShadow = false
            window.backgroundColor = .black
            window.isReleasedWhenClosed = false

            let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.wantsLayer = true
            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspectFill // fill the screen, crop edges if needed
            layer.frame = view.bounds
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            view.layer?.addSublayer(layer)

            window.contentView = view
            window.orderFront(nil)
            windows.append(window)
        }
    }
}
