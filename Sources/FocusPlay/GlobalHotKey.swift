import AppKit
import Carbon.HIToolbox

/// 앱이 비활성(메뉴바 전용 LSUIElement)이어도 동작하는 전역 단축키.
/// Carbon RegisterEventHotKey 사용 — 입력 모니터링 권한이 필요 없고, 이벤트를 소비하므로
/// 다른 앱의 같은 키와 충돌하지 않는다. (NSMenuItem 의 keyEquivalent 는 앱이 활성일 때만
/// 동작하므로 메뉴바 전용 앱의 전역 단축키로는 쓸 수 없다.)
@MainActor
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    fileprivate let action: () -> Void

    /// keyCode 는 Carbon 가상 키코드(예: kVK_ANSI_D), modifiers 는 Carbon 마스크(cmdKey 등)의 OR.
    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: OSType(kEventHotKeyPressed))
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        guard InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &spec, ptr, &eventHandler) == noErr else {
            return nil
        }
        let hotKeyID = EventHotKeyID(signature: OSType(0x46504859) /* 'FPHY' */, id: 1)
        guard RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef) == noErr else {
            RemoveEventHandler(eventHandler)
            return nil
        }
    }

    fileprivate func fire() { action() }

    /// 등록 해제. 단축키를 바꿔 재등록하기 전에 호출한다(중복 등록 방지).
    func invalidate() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        if let eventHandler { RemoveEventHandler(eventHandler); self.eventHandler = nil }
    }
}

/// Carbon 핫키 콜백(캡처 없는 전역 함수여야 C 함수 포인터로 전달 가능).
/// 핫키 이벤트는 메인 런루프에서 디스패치되므로 MainActor 격리를 가정해도 안전하다.
private func hotKeyHandler(_ call: EventHandlerCallRef?,
                           _ event: EventRef?,
                           _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated { hotKey.fire() }
    return noErr
}
