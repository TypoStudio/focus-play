import AppKit

/// 한 모니터를 덮는 검은 오버레이 윈도우.
/// 전체화면 Space 위에도 떠야 하므로 collectionBehavior 와 높은 윈도우 레벨을 사용한다.
/// 클릭은 통과시켜 아래 콘텐츠 조작을 방해하지 않는다.
@MainActor
final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .black
        alphaValue = 0                       // dim 정도는 alphaValue 로 제어 (0 = 투명)
        ignoresMouseEvents = true            // 클릭 통과
        hasShadow = false
        isReleasedWhenClosed = false

        // 로그인 쉴드보다 한 단계 아래 → 시스템 UI(메뉴, 알림)는 가리지 않으면서 일반 앱 위에 위치
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) - 1)

        // 모든 Space + 전체화면 Space 위에 함께 표시, 스페이스 전환 시 따라다니지 않음
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        setFrame(screen.frame, display: true)
        orderFrontRegardless()
    }

    /// 목표 dim 강도로 부드럽게 전환. 0이면 완전히 투명(밝음), 1이면 완전한 검정.
    func setDim(_ target: CGFloat, animated: Bool = true) {
        let clamped = max(0, min(1, target))
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                animator().alphaValue = clamped
            }
        } else {
            alphaValue = clamped
        }
    }
}
