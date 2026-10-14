# LiveWall

LiveWall is a lightweight macOS menu-bar app that turns local video files into
animated desktop wallpapers. It uses a single synchronized video player across
all connected displays and keeps running without a Dock icon or a main window.

## Features

- Import multiple `.mp4` and `.mov` videos into a local library.
- Select a video from the menu-bar popover and play it on the desktop.
- Loop the selected video continuously.
- Display the same wallpaper on every connected screen.
- Pause, resume, mute, or stop the current wallpaper.
- Restore the last selected wallpaper after relaunch.
- Rebuild wallpaper windows when displays are connected, disconnected, or
  reconfigured.
- Generate and cache video thumbnails for the library.
- Optionally launch LiveWall automatically at login.
- Store imported videos inside the app's Application Support directory rather
  than depending on their original locations.

## Requirements

- macOS 26.6 or later
- Xcode with Swift 5 support
- A Mac capable of playing the selected local video files

The deployment target is defined in the Xcode project. Video playback
performance depends on the resolution, codec, and number of connected displays.

## Getting started

1. Clone the repository:

   ```bash
   git clone https://github.com/sanyamk0/LiveWall.git
   cd LiveWall
   ```

2. Open the project in Xcode:

   ```bash
   open LiveWall.xcodeproj
   ```

3. Select the **LiveWall** scheme and a Mac destination.

4. Build and run the app with **Product > Run**.

LiveWall appears in the menu bar. Click its icon and choose **Add Videos…** to
import one or more video files. Selecting a video starts it immediately as the
wallpaper. The first imported video is selected automatically when the library
is empty.

## Using LiveWall

Open the menu-bar popover to:

- Click a thumbnail to set that video as the wallpaper.
- Use the play/pause button to control playback.
- Use the speaker button to mute or unmute the video.
- Use the delete control or the context menu to remove a video from the
  library.
- Choose **Stop Wallpaper** to remove the LiveWall windows and return to the
  normal macOS wallpaper.
- Enable **Launch at login** to start the app automatically.
- Choose **Quit LiveWall** to exit the app.

By default, audio is muted. The wallpaper windows ignore mouse events, so they
remain behind normal desktop interaction.

## Data storage

Imported videos and the library index are stored under the app's
Application Support directory:

```text
~/Library/Application Support/LiveWall/
├── library.json
└── Videos/
```

When running with App Sandbox enabled, macOS places this data inside the
application container. The app copies imported files into this directory, so
the originals can be moved or deleted without breaking the library.

## Project structure

| File | Responsibility |
| --- | --- |
| `LiveWallApp.swift` | App entry point, menu-bar scene, and application startup |
| `MenuView.swift` | Menu-bar popover, library controls, and import actions |
| `VideoLibrary.swift` | Video importing, persistence, and current-wallpaper state |
| `WallpaperManager.swift` | Desktop-level windows, AVPlayer playback, looping, and display changes |
| `Thumbnails.swift` | Asynchronous video thumbnail generation and in-memory caching |

The app uses SwiftUI for its interface, AppKit for menu-bar and desktop
windows, AVFoundation for video playback and thumbnails, and
`ServiceManagement` for launch-at-login registration.

## Limitations

- LiveWall currently supports local video files only; it does not download or
  stream wallpapers.
- The same video is shown on every display.
- Imported videos are copied, so disk usage includes a second copy of each
  file.
- There is no packaged installer or prebuilt release in this repository.
- The app relies on the current Xcode project signing configuration. You may
  need to choose your own development team in Xcode when building locally.

## License

No license has been specified for this repository yet.
