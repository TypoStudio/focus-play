import AppKit
import SwiftUI

/// 환경설정 스타일 설정 윈도우. 고정 크기 컨테이너에 자식 뷰(일반/정보)만 교체하고, 상단 NSToolbar
/// (.preference 스타일)에 아이콘+라벨 탭을 둔다. 윈도우 크기를 고정하므로 탭 전환 시 위치·크기가
/// 변하지 않고, 타이틀도 직접 설정한다. (NSTabViewController 는 크기를 자체 계산하고 타이틀을
/// 비워 버려 적합하지 않았다.)
@MainActor
final class SettingsWindowController: NSObject, NSToolbarDelegate {
    private static let generalID = NSToolbarItem.Identifier("general")
    private static let aboutID = NSToolbarItem.Identifier("about")
    private static let contentSize = NSSize(width: 360, height: 220)

    private let window: NSWindow
    private let container = NSView()
    private let generalVC: NSViewController
    private let aboutVC: NSViewController

    init(controller: DimController, hotKeyStore: HotKeyStore) {
        generalVC = NSHostingController(rootView: GeneralSettingsView(controller: controller, hotKeyStore: hotKeyStore))
        aboutVC = NSHostingController(rootView: AboutView())

        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        container.frame = NSRect(origin: .zero, size: Self.contentSize)
        window.contentView = container

        super.init()

        let toolbar = NSToolbar(identifier: "settings")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        toolbar.selectedItemIdentifier = Self.generalID
        window.toolbar = toolbar
        window.toolbarStyle = .preference

        switchTo(Self.generalID)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func selectTab(_ sender: NSToolbarItem) {
        switchTo(sender.itemIdentifier)
    }

    private func switchTo(_ id: NSToolbarItem.Identifier) {
        let isAbout = (id == Self.aboutID)
        let viewController = isAbout ? aboutVC : generalVC

        container.subviews.forEach { $0.removeFromSuperview() }
        viewController.view.frame = container.bounds
        viewController.view.autoresizingMask = [.width, .height]
        container.addSubview(viewController.view)

        window.title = L(isAbout ? "settings.tab_about" : "settings.tab_general")
        window.toolbar?.selectedItemIdentifier = id
    }

    // MARK: - NSToolbarDelegate

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        item.target = self
        item.action = #selector(selectTab(_:))
        if id == Self.aboutID {
            item.label = L("settings.tab_about")
            item.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        } else {
            item.label = L("settings.tab_general")
            item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        }
        return item
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.generalID, Self.aboutID]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.generalID, Self.aboutID]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.generalID, Self.aboutID]
    }
}
