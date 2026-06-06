import AppKit

/// 외부 앱의 전체화면 윈도우를 감지한다.
/// CGWindowList 로 화면에 보이는 일반 앱 윈도우 중, 어떤 모니터의 전체 프레임을
/// (메뉴바 영역 포함) 거의 완전히 덮는 것이 있으면 그 모니터를 "전체화면 중"으로 본다.
/// 일반 최대화 윈도우는 메뉴바 아래에서 시작하므로 전체화면 Space 와 구별된다.
enum FullscreenDetector {

    /// 전체화면 윈도우가 점유 중인 모니터들의 displayID 집합을 반환.
    static func displaysWithFullscreenWindow() -> Set<CGDirectDisplayID> {
        var result = Set<CGDirectDisplayID>()

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return result
        }

        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }
            let screenFrameTop = topLeftFrame(of: screen)   // CGWindow 좌표계(top-left origin)로 변환된 프레임

            for info in infoList {
                // 일반 앱 윈도우만 (layer 0). 메뉴바/Dock/배경 등은 제외.
                let layer = info[kCGWindowLayer as String] as? Int ?? 0
                if layer != 0 { continue }

                guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                      let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                    continue
                }

                if covers(screenFrameTop, with: bounds) {
                    result.insert(displayID)
                    break
                }
            }
        }

        return result
    }

    /// 윈도우가 모니터 전체 프레임을 사실상 덮는지 판정 (작은 오차 허용).
    private static func covers(_ screenFrame: CGRect, with window: CGRect) -> Bool {
        let tolerance: CGFloat = 2
        let coversWidth = window.width >= screenFrame.width - tolerance
        let coversHeight = window.height >= screenFrame.height - tolerance
        let originMatches =
            abs(window.minX - screenFrame.minX) <= tolerance &&
            abs(window.minY - screenFrame.minY) <= tolerance
        return coversWidth && coversHeight && originMatches
    }

    /// NSScreen.frame(bottom-left origin) 을 CGWindow 좌표계(top-left origin)로 변환.
    private static func topLeftFrame(of screen: NSScreen) -> CGRect {
        // 전역 좌표 높이 기준: 주 디스플레이의 상단을 0 으로 하는 flipped 좌표.
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
