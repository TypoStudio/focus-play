import SwiftUI
import ServiceManagement

// 설정창은 NSToolbar 기반 환경설정 윈도우(SettingsWindowController)가 이 두 뷰를 탭으로 호스팅한다.

// MARK: - 일반

struct GeneralSettingsView: View {
    @ObservedObject var controller: DimController
    @ObservedObject var hotKeyStore: HotKeyStore
    @StateObject private var recorder = ShortcutRecorder()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            LabeledContent(L("menu.dim_strength")) {
                HStack(spacing: 10) {
                    Slider(value: $controller.dimStrength, in: 0.5...1.0)
                        .frame(minWidth: 140)
                    Text("\(Int((controller.dimStrength * 100).rounded()))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }

            Toggle(L("menu.brighten_when_paused"), isOn: $controller.brightenWhenPaused)

            Toggle(L("menu.launch_at_login"), isOn: Binding(
                get: { launchAtLogin },
                set: { setLaunchAtLogin($0) }
            ))

            LabeledContent(L("settings.manual_hotkey")) {
                Button(recorder.isRecording ? L("settings.recording") : hotKeyStore.shortcut.display) {
                    recorder.toggle()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360, height: 220)
        .onAppear { recorder.onCapture = { hotKeyStore.shortcut = $0 } }
        .onDisappear { recorder.stop() }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("FocusPlay: 로그인 항목 변경 실패 - \(error.localizedDescription)")
        }
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }
}

// MARK: - 정보

struct AboutView: View {
    private let githubURL = URL(string: "https://github.com/TypoStudio/focus-play")!
    private let bmcURL = URL(string: "https://www.buymeacoffee.com/typ0s2d10")!

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text("FocusPlay")
                        .font(.headline)
                    Text(versionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text(copyright)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 12) {
                imageLink("github", url: githubURL)
                imageLink("bmc_button", url: bmcURL)
            }
        }
        .padding()
        .frame(width: 360, height: 220)
    }

    private func imageLink(_ name: String, url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            if let image = resourceImage(name) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 34)
            } else {
                Text(url.host ?? name)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private func resourceImage(_ name: String) -> NSImage? {
        guard let url = resourceBundle.url(forResource: name, withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "v\(version) (\($0))" } ?? "v\(version)"
    }

    private var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "© TypoStudio"
    }
}
