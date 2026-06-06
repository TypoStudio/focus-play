import AppKit

@MainActor
final class DimController {

    enum Mode {
        case auto      // 외부 앱 전체화면 감지 시 자동으로 나머지 모니터를 어둡게
        case manual    // 사용자가 토글한 동안 마우스 없는 모니터를 어둡게
        case off       // 비활성
    }

    private(set) var mode: Mode = .auto
    var dimStrength: CGFloat = 0.98          // 0~1, 어둠 강도 (기본 98%)

    private var overlays: [CGDirectDisplayID: OverlayWindow] = [:]
    private var pollTimer: Timer?
    private var lastFullscreenDisplays: Set<CGDirectDisplayID> = []

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
            lastFullscreenDisplays = FullscreenDetector.displaysWithFullscreenWindow()
        }
        update()
    }

    /// 현재 상태에 따라 각 모니터 오버레이의 dim 을 갱신.
    private func update() {
        let mouseDisplay = displayUnderMouse()
        let engaged = isEngaged

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
        }
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
