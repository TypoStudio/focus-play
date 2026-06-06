<p align="center">
  <img src="assets/title.png" alt="FocusPlay" width="100%">
</p>

<p align="center">
  <a href="README.md">한국어</a> · <b>English</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013+-0a84ff?style=flat-square&logo=apple&logoColor=white" alt="platform">
  <img src="https://img.shields.io/badge/Swift-6.0-f05138?style=flat-square&logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/menu%20bar%20app-7c8cf8?style=flat-square" alt="menu bar app">
  <img src="https://img.shields.io/badge/SwiftPM-build-brightgreen?style=flat-square&logo=swift&logoColor=white" alt="SwiftPM">
  <img src="https://img.shields.io/badge/permissions-none-success?style=flat-square" alt="no permissions">
</p>

# FocusPlay

A macOS menu bar app that **automatically dims your other monitors when a video plays fullscreen on one of them**. While you focus on the video, the bright screens on your other displays no longer distract you.

<p align="center">
  <img src="assets/demo.png" alt="How it works" width="100%">
</p>

## Features

- 🎬 **Automatic fullscreen video detection** — only the monitor playing fullscreen video stays bright; the rest are covered with a black overlay.
- 🖱️ **Follows your mouse** — move the cursor onto a dimmed monitor and it brightens again; move away and it dims back.
- 🔄 **Auto restore** — exit fullscreen and every monitor returns to its original brightness.
- 🎯 **Video only** — fullscreen text editors, documents, and other non-video apps are *not* dimmed.
- 🌗 **Adjustable dim strength** — 70 / 85 / 92 / 98 / 100% (default 98%).
- ⏸️ **Pause behavior option** — choose whether to brighten when playback pauses (default: stay dimmed while fullscreen is held).
- 🔒 **No permissions required** — works without Accessibility or Screen Recording permissions.
- 🌐 **Localized** — Korean, English, Japanese, Chinese (Simplified/Traditional), Spanish, Hindi.

## Install & Run

### Quick run (development)

```bash
swift run
```

A 🌙 icon appears in the menu bar (it does not show in the Dock).

### Build a distributable app

```bash
./scripts/build-app.sh
```

This produces `build/FocusPlay.app`. Move it to `/Applications`. To launch at login, add it under **System Settings → General → Login Items**.

> The app is unsigned, so on first launch right-click → **Open** to allow it past Gatekeeper.

## Usage

Click the 🌙 menu bar icon:

| Menu | Description |
|------|-------------|
| **Automatic (detect fullscreen)** | Detect fullscreen video and dim automatically (default) |
| **Manual toggle** (`⌘D`) | Dim the monitors without the mouse, without video detection |
| **Off** | Disable |
| **Dim strength** | Choose 70 – 100% |
| **Brighten when playback pauses** | When on, brightens as soon as playback pauses (default off) |

## How it works

"Fullscreen video" is determined by combining two signals — a window that fills the screen (fullscreen), and a sign that video is playing on that screen.

- **Fullscreen detection**: `CGWindowList` finds an app window that covers the screen (including the menu bar area). A regular maximized window starts below the menu bar, so it is excluded; on notched MacBook displays the menu bar height (`safeAreaInsets`) is compensated for.
- **Video detection**:
  - Native video players (IINA, QuickTime, VLC, etc.) are recognized **by app name**.
  - Browsers and PWAs (YouTube, Disney+, etc.) are recognized by the **display-sleep prevention assertion** they hold while playing (`IOPMCopyAssertionsByProcess`). For PWAs the window process and the assertion process differ, so instead of matching PIDs the two signals are debounced and combined independently.
- **Overlay**: a `borderless` black window covers each monitor, floats above fullscreen Spaces (`fullScreenAuxiliary`), and passes clicks through.

### Supported video players

IINA · QuickTime Player · VLC · mpv · Movist / Movist Pro · Infuse · Elmedia Player · PotPlayer
plus any browser or PWA that holds a video-playback assertion (Chrome · Safari · YouTube · Disney+, etc.).

> To add a player that isn't listed, add its app name to `videoPlayers` in `DimController.swift`.

## Requirements

- macOS 13 (Ventura) or later
- Swift 6.0 toolchain (Xcode 16+)

## Project structure

```
Sources/FocusPlay/
├── main.swift               # Entry point (.accessory policy = menu bar only)
├── AppDelegate.swift        # Menu bar UI
├── DimController.swift      # Polling, signal combination, overlay dimming
├── FullscreenDetector.swift # Collects fullscreen + video-playback signals
├── OverlayWindow.swift      # Black overlay window covering a monitor
└── Localization.swift       # Localized string helper
```
