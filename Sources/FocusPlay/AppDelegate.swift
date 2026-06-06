import AppKit
import ServiceManagement

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

        // 앱 이름 + 버전 (Info.plist 기준, 개발 실행 시 fallback)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let titleItem = NSMenuItem(title: "FocusPlay \(version)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        // 모드 선택
        let autoItem = NSMenuItem(title: L("menu.auto"), action: #selector(selectAuto), keyEquivalent: "")
        autoItem.target = self
        autoItem.state = controller.mode == .auto ? .on : .off
        menu.addItem(autoItem)

        let manualItem = NSMenuItem(title: L("menu.manual"), action: #selector(toggleManual), keyEquivalent: "d")
        manualItem.target = self
        manualItem.state = (controller.mode == .manual && controller.isEngaged) ? .on : .off
        menu.addItem(manualItem)

        let offItem = NSMenuItem(title: L("menu.off"), action: #selector(selectOff), keyEquivalent: "")
        offItem.target = self
        offItem.state = controller.mode == .off ? .on : .off
        menu.addItem(offItem)

        menu.addItem(.separator())

        // 어둠 강도
        let dimHeader = NSMenuItem(title: L("menu.dim_strength"), action: nil, keyEquivalent: "")
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

        let pauseItem = NSMenuItem(title: L("menu.brighten_when_paused"), action: #selector(toggleBrightenWhenPaused), keyEquivalent: "")
        pauseItem.target = self
        pauseItem.state = controller.brightenWhenPaused ? .on : .off
        menu.addItem(pauseItem)

        let loginItem = NSMenuItem(title: L("menu.launch_at_login"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        // 저작권 (Info.plist NSHumanReadableCopyright 기준)
        let copyright = Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "© TypoStudio"
        let copyrightItem = NSMenuItem(title: copyright, action: nil, keyEquivalent: "")
        copyrightItem.isEnabled = false
        menu.addItem(copyrightItem)

        let quitItem = NSMenuItem(title: L("menu.quit"), action: #selector(quit), keyEquivalent: "q")
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

    @objc private func toggleBrightenWhenPaused() {
        controller.brightenWhenPaused.toggle()
        rebuildMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("FocusPlay: 로그인 항목 등록 실패 - \(error.localizedDescription)")
        }
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
