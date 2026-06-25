import AppKit
import Combine
import Carbon.HIToolbox

/// 전역 단축키 한 조합. Carbon 키코드/마스크(등록용)와 표시 라벨을 함께 보관한다.
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var keyLabel: String

    static let `default` = Shortcut(
        keyCode: UInt32(kVK_ANSI_D),
        carbonModifiers: UInt32(controlKey | optionKey | cmdKey),
        keyLabel: "D"
    )

    /// 메뉴·설정창 표시용 문자열(예: ⌃⌥⌘D).
    var display: String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s + keyLabel
    }

    /// NSMenuItem 표시·활성 시 동작용 수정자 플래그.
    var nsModifierFlags: NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(controlKey) != 0 { f.insert(.control) }
        if carbonModifiers & UInt32(optionKey)  != 0 { f.insert(.option) }
        if carbonModifiers & UInt32(shiftKey)   != 0 { f.insert(.shift) }
        if carbonModifiers & UInt32(cmdKey)     != 0 { f.insert(.command) }
        return f
    }

    init(keyCode: UInt32, carbonModifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.keyLabel = keyLabel
    }

    /// keyDown 이벤트에서 단축키를 구성. 수정자가 하나도 없거나 표시 문자가 없으면 nil
    /// (전역 핫키는 수정자 조합이 있어야 다른 앱과 충돌하지 않는다).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        guard carbon != 0 else { return nil }

        let label = (event.charactersIgnoringModifiers ?? "").uppercased()
        guard label.count == 1, let scalar = label.unicodeScalars.first,
              CharacterSet.alphanumerics.contains(scalar) else { return nil }

        self.keyCode = UInt32(event.keyCode)
        self.carbonModifiers = carbon
        self.keyLabel = label
    }
}

/// 수동 어둡게 전역 단축키를 영속 저장·발행한다.
@MainActor
final class HotKeyStore: ObservableObject {
    private static let key = "manualShortcut"

    @Published var shortcut: Shortcut {
        didSet {
            if let data = try? JSONEncoder().encode(shortcut) {
                UserDefaults.standard.set(data, forKey: Self.key)
            }
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(Shortcut.self, from: data) {
            shortcut = saved
        } else {
            shortcut = .default
        }
    }
}

/// 설정창에서 단축키를 녹화한다. reference type 이라 SwiftUI View(struct)의 @State 복사본
/// 문제 없이 녹화 상태를 안정적으로 발행한다(이게 클로저 캡처로 인한 "재설정 불가" 버그의 원인이었다).
@MainActor
final class ShortcutRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    private var monitor: Any?

    /// 새 단축키를 캡처했을 때 호출. 설정창에서 HotKeyStore 에 반영한다.
    var onCapture: ((Shortcut) -> Void)?

    func toggle() { isRecording ? stop() : start() }

    func start() {
        guard !isRecording else { return }
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
            // NSEvent 는 Sendable 이 아니므로 여기(메인 스레드)에서 값만 추출해 넘긴다.
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let captured = Shortcut(event: event)
            MainActor.assumeIsolated {
                guard let self else { return }
                if isEscape {
                    self.stop()
                } else if let captured {
                    self.onCapture?(captured)
                    self.stop()
                }
            }
            return nil   // 녹화 중에는 이벤트를 소비한다.
        }
    }

    func stop() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
