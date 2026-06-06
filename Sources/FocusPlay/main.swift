import AppKit

// 메뉴바 전용 앱: Dock에 표시하지 않고 메뉴바 아이콘으로만 동작.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
