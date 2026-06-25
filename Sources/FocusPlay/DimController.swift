import AppKit
import Combine

@MainActor
final class DimController: ObservableObject {

    enum Mode {
        case auto      // 외부 앱 전체화면 영상 감지 시 자동으로 나머지 모니터를 어둡게
        case off       // 비활성
    }

    private static let pauseKey = "brightenWhenPaused"
    private static let dimKey = "dimStrength"

    private(set) var mode: Mode = .auto

    // 0~1, 어둠 강도 (기본 98%). 설정창 슬라이더와 바인딩.
    @Published var dimStrength: CGFloat = (UserDefaults.standard.object(forKey: DimController.dimKey) as? Double).map { CGFloat($0) } ?? 0.98 {
        didSet {
            UserDefaults.standard.set(Double(dimStrength), forKey: Self.dimKey)
            update()
        }
    }

    // 재생을 멈추면 자동으로 밝게 할지. 기본은 false(전체화면 유지되는 동안 계속 어둡게).
    @Published var brightenWhenPaused: Bool = UserDefaults.standard.bool(forKey: DimController.pauseKey) {
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

    // full(디스플레이별)·videoFullscreenDirect(디스플레이별) 신호가 깜빡이므로 각각 디바운스한다.
    private var fullMiss: [CGDirectDisplayID: Int] = [:]
    private var lastOwner: [CGDirectDisplayID: String] = [:]
    // "영상 전체화면"이 한 번 확인된 디스플레이(전체화면이 유지되는 한 sticky).
    private var videoConfirmed: [CGDirectDisplayID: Bool] = [:]
    private var videoMissDirect: [CGDirectDisplayID: Int] = [:]
    private let signalThreshold = 8         // 0.12s × 8 ≈ 1초 연속 false 여야 신호 해제

    // 수동 어둡게: 자동 감지가 안 잡히는 앱(크롬앱 PWA 영상 등)에서 ⌘D 로 직접 켠다.
    // 자동 감지(lastFullscreenDisplays)와 독립적으로 동작하며, 켜지면 마우스 있는 화면만 밝게 둔다.
    private(set) var manualActive = false

    /// 현재 집중 모드가 화면을 어둡게 만들 수 있는 상태인지(메뉴 체크표시용).
    var isEngaged: Bool {
        switch mode {
        case .auto: return !lastFullscreenDisplays.isEmpty || manualActive
        case .off:  return false
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

    /// 수동 어둡게 토글(⌘D). 모드를 바꾸지 않으므로 자동 모드 위에서도 동작한다.
    func toggleManualDim() {
        manualActive.toggle()
        update()
    }

    // MARK: - Polling

    private func tick() {
        if mode == .auto {
            let scan = FullscreenDetector.scan()

            var newSet = Set<CGDirectDisplayID>()
            for screen in NSScreen.screens {
                guard let id = screen.displayID else { continue }

                // 전체화면(디스플레이별) 신호 디바운스 + owner 기억.
                if let owner = scan.fullscreenOwners[id] {
                    fullMiss[id] = 0
                    lastOwner[id] = owner
                } else {
                    fullMiss[id] = (fullMiss[id] ?? signalThreshold) + 1
                }
                let fullRecent = (fullMiss[id] ?? signalThreshold) < signalThreshold
                if !fullRecent {
                    lastOwner[id] = nil
                    videoConfirmed[id] = false
                }

                // 전체화면 윈도우 owner 가 직접 재생 신호를 가진 디스플레이(엄격 신호) 디바운스.
                videoMissDirect[id] = scan.videoFullscreensDirect.contains(id) ? 0 : (videoMissDirect[id] ?? signalThreshold) + 1
                let ownerDirectRecent = (videoMissDirect[id] ?? signalThreshold) < signalThreshold

                // 영상 = (네이티브 플레이어 앱) OR (전체화면 윈도우 자신이 영상 소스 = 직접 재생 신호 보유).
                // 다른 창·다른 모니터에서 영상이 재생 중이어도 전체화면 윈도우가 그 소스가 아니면 어둡게 하지 않는다.
                // PWA(크롬앱)는 윈도우 PID 와 재생 PID 가 갈려 자동 감지되지 않으므로 수동(⌘D)으로 처리한다.
                let isVideoPlayer = lastOwner[id].map { videoPlayers.contains($0) } ?? false
                let isVideo = isVideoPlayer || ownerDirectRecent
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
