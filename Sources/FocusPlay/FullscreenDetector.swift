import AppKit
import IOKit.pwr_mgt

/// 두 신호를 독립적으로 수집한다(판정·디바운스는 호출 측에서 결합):
///  - full: 화면을 메뉴바 영역까지 꽉 채운 일반 앱 윈도우가 있는 디스플레이들
///  - playing: 시스템에 영상 재생(디스플레이 sleep 방지 assertion)이 하나라도 있는가
/// PWA 는 윈도우 프로세스(app_mode_loader)와 영상 assertion 프로세스(Chrome 본체)가 달라
/// PID 매칭이 불가능하므로, PID 를 맞추지 않고 두 신호를 각각 디바운스해 결합한다.
enum FullscreenDetector {

    private static let debugEnabled = ProcessInfo.processInfo.environment["FOCUSPLAY_DEBUG"] != nil
    nonisolated(unsafe) private static var lastDbg = ""
    private static func dbg(_ s: String) {
        guard debugEnabled, s != lastDbg else { return }
        lastDbg = s
        FileHandle.standardError.write(Data((s + "\n").utf8))
    }

    // 미션컨트롤·Dock·배경 등 시스템 UI 의 풀스크린 윈도우를 전체화면으로 오인하지 않도록 제외.
    private static let excludedOwners: Set<String> = ["Dock", "Window Server", "WindowServer", "Wallpaper"]

    struct Scan {
        var fullscreenOwners: [CGDirectDisplayID: String] = [:]   // 전체화면 윈도우의 owner 앱 이름
        var playing = false                                        // 시스템에 영상 재생 assertion 존재
    }

    static func scan() -> Scan {
        var scan = Scan()
        let playingPIDs = displaySleepBlockingPIDs()
        scan.playing = !playingPIDs.isEmpty

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return scan
        }

        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }
            let screenFrameTop = topLeftFrame(of: screen)   // CGWindow 좌표계(top-left origin)
            let topInset = screen.safeAreaInsets.top         // 노치/메뉴바 높이 (외장 0, 맥북 노치 32)

            for info in infoList {
                let layer = info[kCGWindowLayer as String] as? Int ?? 0
                if layer != 0 { continue }

                let owner = info[kCGWindowOwnerName as String] as? String ?? ""
                if excludedOwners.contains(owner) { continue }

                guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                      let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                    continue
                }

                if covers(screenFrameTop, with: bounds, topInset: topInset) {
                    scan.fullscreenOwners[displayID] = owner
                    break
                }
            }
        }

        dbg("playing=\(scan.playing) playingPIDs=\(playingPIDs.sorted()) full=\(scan.fullscreenOwners.map { "d\($0.key):\($0.value)" }.sorted())")
        return scan
    }

    /// 디스플레이가 꺼지지 않게 막는 assertion(= 영상 재생 신호)을 가진 프로세스 PID 집합.
    private static func displaySleepBlockingPIDs() -> Set<pid_t> {
        var pids = Set<pid_t>()

        var assertionsRef: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&assertionsRef) == kIOReturnSuccess,
              let byPID = assertionsRef?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else {
            return pids
        }

        for (pidNumber, assertions) in byPID {
            for assertion in assertions {
                let type = assertion[kIOPMAssertionTypeKey as String] as? String ?? ""
                // "...Display..." 류만(영상 재생 신호). 단 시스템(powerd)이 거는 Internal 류는 제외.
                if type.localizedCaseInsensitiveContains("display"),
                   !type.localizedCaseInsensitiveContains("internal") {
                    pids.insert(pid_t(truncating: pidNumber))
                    break
                }
            }
        }

        return pids
    }

    /// 윈도우가 모니터 전체 프레임을 사실상 덮는지 판정 (작은 오차 허용).
    /// 노치 디스플레이는 전체화면이어도 상단 메뉴바 영역(topInset)이 비므로 그만큼 추가 허용.
    /// 일반 최대화 창은 메뉴바 아래에서 시작하므로 originMatches 에서 걸러진다.
    private static func covers(_ screenFrame: CGRect, with window: CGRect, topInset: CGFloat) -> Bool {
        let tolerance: CGFloat = 2
        let topAllow = tolerance + topInset + 4

        let coversWidth = window.width >= screenFrame.width - tolerance
        let coversHeight = window.height >= screenFrame.height - topAllow
        let originMatches =
            abs(window.minX - screenFrame.minX) <= tolerance &&
            window.minY >= screenFrame.minY - tolerance &&
            window.minY <= screenFrame.minY + topAllow
        return coversWidth && coversHeight && originMatches
    }

    /// NSScreen.frame(bottom-left origin) 을 CGWindow 좌표계(top-left origin)로 변환.
    private static func topLeftFrame(of screen: NSScreen) -> CGRect {
        guard let primary = NSScreen.screens.first else { return screen.frame }
        let primaryTop = primary.frame.maxY
        let f = screen.frame
        let flippedY = primaryTop - f.maxY
        return CGRect(x: f.minX, y: flippedY, width: f.width, height: f.height)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
