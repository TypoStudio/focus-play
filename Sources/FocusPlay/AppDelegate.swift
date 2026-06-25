import AppKit
import SwiftUI
import Combine
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let controller = DimController()
    private let hotKeyStore = HotKeyStore()
    private var manualHotKey: GlobalHotKey?
    private var settingsController: SettingsWindowController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
        setupStatusItem()

        // 수동 어둡게 전역 단축키: 메뉴바 전용 앱이라 메뉴 keyEquivalent 는 비활성 시 안 먹으므로
        // 전역 핫키로 등록한다. 설정창에서 단축키가 바뀌면 재등록한다.
        registerManualHotKey()
        hotKeyStore.$shortcut
            .dropFirst()
            .sink { [weak self] _ in self?.registerManualHotKey() }
            .store(in: &cancellables)
    }

    private func registerManualHotKey() {
        manualHotKey?.invalidate()
        let shortcut = hotKeyStore.shortcut
        manualHotKey = GlobalHotKey(keyCode: shortcut.keyCode, modifiers: shortcut.carbonModifiers) { [weak self] in
            self?.toggleManualDim()
        }
        rebuildMenu()
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "moon.stars.fill",
                accessibilityDescription: "FocusPlay"
            )
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // 버전 + 빌드 번호 (Info.plist 기준, 개발 실행 시 fallback)
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String
        let title = build.map { "FocusPlay \(version) (\($0))" } ?? "FocusPlay \(version)"
        let titleItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        // 저작권 (Info.plist NSHumanReadableCopyright 기준)
        let copyright = info?["NSHumanReadableCopyright"] as? String ?? "© TypoStudio"
        let copyrightItem = NSMenuItem(title: copyright, action: nil, keyEquivalent: "")
        copyrightItem.isEnabled = false
        menu.addItem(copyrightItem)

        menu.addItem(.separator())

        // ON/OFF (활성화 토글). 상태를 체크마크 대신 아이콘으로 표시해 좌측 아이콘 열로 정렬을 통일한다.
        let enabledItem = NSMenuItem(title: L("menu.enabled"), action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.image = menuSymbol(controller.mode == .auto ? "checkmark.circle.fill" : "circle")
        menu.addItem(enabledItem)

        // 수동 어둡게(단축키): 자동 감지가 안 잡히는 앱(크롬앱 PWA 영상 등)에서 직접 켠다. 자동 모드 위에서도 동작.
        let shortcut = hotKeyStore.shortcut
        let manualItem = NSMenuItem(title: L("menu.manual"), action: #selector(toggleManualDim), keyEquivalent: shortcut.keyLabel.lowercased())
        manualItem.keyEquivalentModifierMask = shortcut.nsModifierFlags
        manualItem.target = self
        manualItem.image = menuSymbol(controller.manualActive ? "moon.fill" : "moon")
        menu.addItem(manualItem)

        // 설정창 열기
        let settingsItem = NSMenuItem(title: L("menu.settings"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = menuSymbol("gearshape")
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L("menu.quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = menuSymbol("power")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    /// 메뉴 항목용 SF Symbol 아이콘.
    private func menuSymbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        controller.setMode(controller.mode == .auto ? .off : .auto)
        rebuildMenu()
    }

    @objc private func toggleManualDim() {
        controller.toggleManualDim()
        rebuildMenu()
    }

    @objc private func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(controller: controller, hotKeyStore: hotKeyStore)
        }
        settingsController?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
