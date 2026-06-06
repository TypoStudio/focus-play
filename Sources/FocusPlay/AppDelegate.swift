import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let controller = DimController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
        setupStatusItem()
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

        // 모드 선택
        let autoItem = NSMenuItem(title: "자동 (전체화면 감지)", action: #selector(selectAuto), keyEquivalent: "")
        autoItem.target = self
        autoItem.state = controller.mode == .auto ? .on : .off
        menu.addItem(autoItem)

        let manualItem = NSMenuItem(title: "수동 토글", action: #selector(toggleManual), keyEquivalent: "d")
        manualItem.target = self
        manualItem.state = (controller.mode == .manual && controller.isEngaged) ? .on : .off
        menu.addItem(manualItem)

        let offItem = NSMenuItem(title: "끄기", action: #selector(selectOff), keyEquivalent: "")
        offItem.target = self
        offItem.state = controller.mode == .off ? .on : .off
        menu.addItem(offItem)

        menu.addItem(.separator())

        // 어둠 강도
        let dimHeader = NSMenuItem(title: "어둠 강도", action: nil, keyEquivalent: "")
        dimHeader.isEnabled = false
        menu.addItem(dimHeader)

        for percent in [70, 85, 92, 98, 100] {
            let item = NSMenuItem(title: "  \(percent)%", action: #selector(setDim(_:)), keyEquivalent: "")
            item.target = self
            item.tag = percent
            item.state = Int(controller.dimStrength * 100) == percent ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func selectAuto() {
        controller.setMode(.auto)
        rebuildMenu()
    }

    @objc private func toggleManual() {
        controller.toggleManual()
        rebuildMenu()
    }

    @objc private func selectOff() {
        controller.setMode(.off)
        rebuildMenu()
    }

    @objc private func setDim(_ sender: NSMenuItem) {
        controller.setDimStrength(CGFloat(sender.tag) / 100.0)
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
