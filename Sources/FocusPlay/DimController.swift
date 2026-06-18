import AppKit

@MainActor
final class DimController {

    enum Mode {
        case auto      // 외부 앱 전체화면 감지 시 자동으로 나머지 모니터를 어둡게
        case manual    // 사용자가 토글한 동안 마우스 없는 모니터를 어둡게
        case off       // 비활성
    }

    private static let pauseKey = "brightenWhenPaused"

    private(set) var mode: Mode = .auto
    var dimStrength: CGFloat = 0.98          // 0~1, 어둠 강도 (기본 98%)

    // 재생을 멈추면 자동으로 밝게 할지. 기본은 false(전체화면 유지되는 동안 계속 어둡게).
    var brightenWhenPaused: Bool = UserDefaults.standard.bool(forKey: DimController.pauseKey) {
        didSet {
            UserDefaults.standard.set(brightenWhenPaused, forKey: Self.pauseKey)
            update()
        }
    }

    private var overlays: [CGDirectDisplayID: OverlayWindow] = [:]
    private var pollTimer: Timer?
    private var lastFullscreenDisplays: Set<CGDirectDisplayID> = []

    // 네이티브 영상 플레이어는 assertion 이 API 로 안 잡히므로 앱 이름으로 판정한다.
    private let videoPlayers: Set<String> = [
        "IINA", "QuickTime Player", "VLC", "mpv", "Movist", "Movist Pro",
        "Infuse", "Elmedia Player", "PotPlayer", "MPV"
    ]

    // 브라우저·웹앱(PWA 포함). 전체화면 앱이 이 패밀리이고 시스템에 재생 신호가 있을 때만 영상으로 본다.
    // PWA 번들 ID(com.google.Chrome.app.xxx)는 브라우저 번들 ID 를 접두로 가져 prefix 로 함께 잡힌다.
    private let videoBrowserPrefixes: [String] = [
        "com.google.Chrome", "org.chromium.Chromium", "com.apple.Safari",
        "com.microsoft.edgemac", "com.brave.Browser", "org.mozilla.firefox",
        "company.thebrowser.Browser", "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi", "com.naver.Whale"
    ]

    // full(디스플레이별)·playing(전역)·videoFullscreen(디스플레이별) 신호가 깜빡이므로 각각 디바운스한다.
    private var fullMiss: [CGDirectDisplayID: Int] = [:]
    private var lastOwner: [CGDirectDisplayID: String] = [:]
    private var lastBundleID: [CGDirectDisplayID: String] = [:]
    // "영상 전체화면"이 한 번 확인된 디스플레이(전체화면이 유지되는 한 sticky).
    private var videoConfirmed: [CGDirectDisplayID: Bool] = [:]
    private var playingMiss = 0
    private var videoMiss: [CGDirectDisplayID: Int] = [:]
    private let signalThreshold = 8         // 0.12s × 8 ≈ 1초 연속 false 여야 신호 해제

    // 자동 모드에서 전체화면이 감지되어야만 동작. 수동 모드에서는 이 플래그로 on/off.
    private var manualActive = false

    /// 현재 집중 모드가 화면을 어둡게 만들 수 있는 상태인지(메뉴 체크표시용).
    var isEngaged: Bool {
        switch mode {
        case .auto:   return !lastFullscreenDisplays.isEmpty
        case .manual: return manualActive
        case .off:    return false
        }
    }

    func start() {
        rebuildOverlays()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // 마우스 추적은 빠르게, 전체화면 감지는 그 위에 얹어 함께 폴링.
        let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    // MARK: - Public controls

    func setMode(_ newMode: Mode) {
        mode = newMode
        if newMode == .off { manualActive = false }
        update()
    }

    func toggleManual() {
        mode = .manual
        manualActive.toggle()
        update()
    }

    func setDimStrength(_ value: CGFloat) {
        dimStrength = max(0, min(1, value))
        update()
    }

    // MARK: - Polling

    private func tick() {
        if mode == .auto {
            let scan = FullscreenDetector.scan()

            // 시스템 영상 재생(전역) 신호 디바운스: 브라우저 전체화면 판정에만 사용.
            playingMiss = scan.playing ? 0 : playingMiss + 1
            let playingRecent = playingMiss < signalThreshold

            var newSet = Set<CGDirectDisplayID>()
            for screen in NSScreen.screens {
                guard let id = screen.displayID else { continue }

                // 전체화면(디스플레이별) 신호 디바운스 + owner/번들 기억.
                if let owner = scan.fullscreenOwners[id] {
                    fullMiss[id] = 0
                    lastOwner[id] = owner
                    lastBundleID[id] = scan.fullscreenBundleIDs[id]
                } else {
                    fullMiss[id] = (fullMiss[id] ?? signalThreshold) + 1
                }
                let fullRecent = (fullMiss[id] ?? signalThreshold) < signalThreshold
                if !fullRecent {
                    lastOwner[id] = nil
                    lastBundleID[id] = nil
                    videoConfirmed[id] = false
                }

                // 전체화면 앱 자신이 재생 assertion 을 가진 디스플레이(정밀 신호) 디바운스.
                videoMiss[id] = scan.videoFullscreens.contains(id) ? 0 : (videoMiss[id] ?? signalThreshold) + 1
                let ownerPlayingRecent = (videoMiss[id] ?? signalThreshold) < signalThreshold

                // 영상 = (네이티브 플레이어 앱) OR (전체화면 앱이 직접 재생 신호 보유)
                //        OR (전체화면 앱이 브라우저·웹앱이고 시스템에 재생 신호가 있음).
                // 영상이 다른 창에서 재생 중이어도 전체화면 앱이 그 영상 소스가 아니면 어둡게 하지 않는다.
                let isVideoPlayer = lastOwner[id].map { videoPlayers.contains($0) } ?? false
                let isBrowser = lastBundleID[id].map { bid in
                    videoBrowserPrefixes.contains { bid == $0 || bid.hasPrefix($0 + ".") }
                } ?? false
                let isVideo = isVideoPlayer || ownerPlayingRecent || (isBrowser && playingRecent)
                if fullRecent && isVideo { videoConfirmed[id] = true }

                // 기본: 한 번 확인되면 전체화면 유지되는 한 어둡게(재생 멈춰도).
                // 옵션 on: 재생 중(영상 신호)일 때만 어둡게 → 멈추면 밝아짐.
                let shouldDim = brightenWhenPaused ? isVideo : (videoConfirmed[id] ?? false)
                if fullRecent && shouldDim {
                    newSet.insert(id)
                }
            }
            lastFullscreenDisplays = newSet
        }
        update()
    }

    /// 현재 상태에 따라 각 모니터 오버레이의 dim 을 갱신.
    private func update() {
        let mouseDisplay = displayUnderMouse()
        let engaged = isEngaged

        var states: [String] = []
        for screen in NSScreen.screens {
            guard let id = screen.displayID, let overlay = overlays[id] else { continue }

            var shouldDim = false
            if engaged {
                let isFullscreenScreen = (mode == .auto) && lastFullscreenDisplays.contains(id)
                let hasMouse = (id == mouseDisplay)
                // 전체화면 영상이 있는 모니터(영상 보는 화면)와 마우스가 올라간 모니터는 밝게.
                shouldDim = !(isFullscreenScreen || hasMouse)
            }

            overlay.setDim(shouldDim ? dimStrength : 0)
            states.append("\(id):\(shouldDim ? "DIM" : "lit")")
        }
        debugLog("lastFS=\(lastFullscreenDisplays.sorted()) mouse=\(mouseDisplay.map(String.init) ?? "nil") engaged=\(engaged) dim=\(dimStrength) | \(states.joined(separator: " "))")
    }

    private let debugEnabled = ProcessInfo.processInfo.environment["FOCUSPLAY_DEBUG"] != nil
    private var lastSnap = ""
    private func debugLog(_ s: String) {
        guard debugEnabled, s != lastSnap else { return }
        lastSnap = s
        FileHandle.standardError.write(Data((s + "\n").utf8))
    }

    private func displayUnderMouse() -> CGDirectDisplayID? {
        let loc = NSEvent.mouseLocation
        for screen in NSScreen.screens where screen.frame.contains(loc) {
            return screen.displayID
        }
        return nil
    }

    // MARK: - Overlay lifecycle

    @objc private func screensChanged() {
        rebuildOverlays()
        update()
    }

    private func rebuildOverlays() {
        for (_, window) in overlays { window.orderOut(nil) }
        overlays.removeAll()

        for screen in NSScreen.screens {
            guard let id = screen.displayID else { continue }
            overlays[id] = OverlayWindow(screen: screen)
        }
    }
}
