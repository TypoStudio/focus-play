<p align="center">
  <img src="assets/title.png" alt="FocusPlay" width="100%">
</p>

<p align="center">
  <b>English</b> · <a href="#korean">한국어</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013+-0a84ff?style=flat-square&logo=apple&logoColor=white" alt="platform">
  <img src="https://img.shields.io/badge/Swift-6.0-f05138?style=flat-square&logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/menu%20bar%20app-7c8cf8?style=flat-square" alt="menu bar app">
  <img src="https://img.shields.io/badge/SwiftPM-build-brightgreen?style=flat-square&logo=swift&logoColor=white" alt="SwiftPM">
  <img src="https://img.shields.io/badge/permissions-none-success?style=flat-square" alt="no permissions">
  <a href="https://github.com/TypoStudio/focus-play/releases/latest"><img src="https://img.shields.io/github/v/release/TypoStudio/focus-play?style=flat-square&logo=apple&logoColor=white&label=download&color=7c8cf8" alt="download"></a>
</p>

# FocusPlay

A macOS menu bar app that **automatically dims your other monitors when a video plays fullscreen on one of them**. While you focus on the video, the bright screens on your other displays no longer distract you.

<p align="center">
  <img src="assets/demo.png" alt="How it works" width="100%">
</p>

## Features

- 🎬 **Automatic fullscreen video detection** — only the monitor playing fullscreen video stays bright; the rest are covered with a black overlay.
- 🖱️ **Follows your mouse** — move the cursor onto a dimmed monitor and it brightens again; move away and it dims back.
- 🔄 **Auto restore** — exit fullscreen and every monitor returns to its original brightness.
- 🎯 **Video only** — fullscreen text editors, documents, and other non-video apps are *not* dimmed.
- 🌗 **Adjustable dim strength** — 70 / 85 / 92 / 98 / 100% (default 98%).
- ⏸️ **Pause behavior option** — choose whether to brighten when playback pauses (default: stay dimmed while fullscreen is held).
- 🔒 **No permissions required** — works without Accessibility or Screen Recording permissions.
- 🌐 **Localized** — Korean, English, Japanese, Chinese (Simplified/Traditional), Spanish, Hindi.

## Install & Run

### Homebrew

```bash
brew install --cask typostudio/tap/focusplay
```

The app is unsigned, so if the first launch is blocked by Gatekeeper, clear the quarantine attribute once.

```bash
xattr -dr com.apple.quarantine /Applications/FocusPlay.app
```

### Download

Grab `FocusPlay-x.y.z.zip` from the [**latest release**](https://github.com/TypoStudio/focus-play/releases/latest), unzip it, and move `FocusPlay.app` to your **Applications** folder. On first launch, right-click → **Open** (unsigned app).

### Quick run (development)

```bash
swift run
```

A 🌙 icon appears in the menu bar (it does not show in the Dock).

### Build a distributable app

```bash
./scripts/build-app.sh
```

This produces `build/FocusPlay.app`. Move it to `/Applications`. To launch at login, add it under **System Settings → General → Login Items**.

> The app is unsigned, so on first launch right-click → **Open** to allow it past Gatekeeper.

## Usage

Click the 🌙 menu bar icon:

| Menu | Description |
|------|-------------|
| **Automatic (detect fullscreen)** | Detect fullscreen video and dim automatically (default) |
| **Manual toggle** (`⌘D`) | Dim the monitors without the mouse, without video detection |
| **Off** | Disable |
| **Dim strength** | Choose 70 – 100% |
| **Brighten when playback pauses** | When on, brightens as soon as playback pauses (default off) |

## How it works

"Fullscreen video" is determined by combining two signals — a window that fills the screen (fullscreen), and a sign that video is playing on that screen.

- **Fullscreen detection**: `CGWindowList` finds an app window that covers the screen (including the menu bar area). A regular maximized window starts below the menu bar, so it is excluded; on notched MacBook displays the menu bar height (`safeAreaInsets`) is compensated for.
- **Video detection**:
  - Native video players (IINA, QuickTime, VLC, etc.) are recognized **by app name**.
  - Browsers and PWAs (YouTube, Disney+, etc.) are recognized by the **display-sleep prevention assertion** they hold while playing (`IOPMCopyAssertionsByProcess`). For PWAs the window process and the assertion process differ, so instead of matching PIDs the two signals are debounced and combined independently.
- **Overlay**: a `borderless` black window covers each monitor, floats above fullscreen Spaces (`fullScreenAuxiliary`), and passes clicks through.

### Supported video players

IINA · QuickTime Player · VLC · mpv · Movist / Movist Pro · Infuse · Elmedia Player · PotPlayer
plus any browser or PWA that holds a video-playback assertion (Chrome · Safari · YouTube · Disney+, etc.).

> To add a player that isn't listed, add its app name to `videoPlayers` in `DimController.swift`.

## Requirements

- macOS 13 (Ventura) or later
- Swift 6.0 toolchain (Xcode 16+)

## Project structure

```
Sources/FocusPlay/
├── main.swift               # Entry point (.accessory policy = menu bar only)
├── AppDelegate.swift        # Menu bar UI
├── DimController.swift      # Polling, signal combination, overlay dimming
├── FullscreenDetector.swift # Collects fullscreen + video-playback signals
├── OverlayWindow.swift      # Black overlay window covering a monitor
└── Localization.swift       # Localized string helper
```

## Support

If you like this app, you can support it with a cup of coffee ☕

<a href="https://www.buymeacoffee.com/typ0s2d10" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/arial-yellow.png" alt="Buy Me A Coffee" height="50"></a>

---

<a id="korean"></a>

<p align="center">
  <a href="#focusplay">English</a> · <b>한국어</b>
</p>

# FocusPlay

여러 모니터를 쓸 때, **한 화면에서 영상을 전체화면으로 재생하면 나머지 모니터를 자동으로 어둡게** 만드는 macOS 메뉴바 앱입니다. 영상에 몰입하는 동안 옆 모니터의 밝은 화면이 시야를 방해하지 않습니다.

<p align="center">
  <img src="assets/demo.png" alt="동작 설명" width="100%">
</p>

## 기능

- 🎬 **전체화면 영상 자동 감지** — 영상이 전체화면으로 재생되는 모니터만 밝게 두고, 나머지를 검은 오버레이로 어둡게 합니다.
- 🖱️ **마우스 따라 복귀** — 어두워진 모니터로 마우스를 옮기면 그 화면만 다시 밝아지고, 빠지면 다시 어두워집니다.
- 🔄 **해제 시 자동 복원** — 전체화면을 해제하면 모든 모니터가 원래 밝기로 돌아옵니다.
- 🎯 **영상만 구분** — 텍스트 에디터·문서 등 영상이 아닌 앱을 전체화면해도 어두워지지 않습니다.
- 🌗 **어둠 강도 조절** — 70 / 85 / 92 / 98 / 100% 중 선택 (기본 98%).
- ⏸️ **일시정지 동작 선택** — 재생을 멈추면 밝게 할지 옵션으로 선택 (기본: 전체화면 유지되는 동안 계속 어둡게).
- 🔒 **권한 불필요** — 접근성·화면 기록 권한 없이 동작합니다.
- 🌐 **다국어 지원** — 한국어·영어·일본어·중국어(간체/번체)·스페인어·힌디어.

## 설치 및 실행

### Homebrew

```bash
brew install --cask typostudio/tap/focusplay
```

서명되지 않은 앱이라 첫 실행이 Gatekeeper에 막히면 격리 속성을 한 번 제거하세요.

```bash
xattr -dr com.apple.quarantine /Applications/FocusPlay.app
```

### 다운로드

[**최신 릴리즈**](https://github.com/TypoStudio/focus-play/releases/latest)에서 `FocusPlay-x.y.z.zip` 을 받아 압축을 풀고, `FocusPlay.app` 을 **응용 프로그램** 폴더로 옮기세요. 첫 실행 시 우클릭 → **열기** (서명되지 않은 앱).

### 빠른 실행 (개발)

```bash
swift run
```

메뉴바에 🌙 아이콘이 나타납니다 (Dock에는 표시되지 않습니다).

### 배포용 앱 빌드

```bash
./scripts/build-app.sh
```

`build/FocusPlay.app` 이 생성됩니다. `/Applications` 로 옮겨 사용하세요. 로그인 시 자동 실행하려면 **시스템 설정 → 일반 → 로그인 항목**에 추가하면 됩니다.

> 서명되지 않은 앱이므로 처음 실행 시 Gatekeeper 경고가 나오면 **우클릭 → 열기**로 한 번 허용하세요.

## 사용법

메뉴바 🌙 아이콘을 클릭하면:

| 메뉴 | 설명 |
|------|------|
| **자동 (전체화면 감지)** | 전체화면 영상을 감지해 자동으로 어둡게 (기본) |
| **수동 토글** (`⌘D`) | 영상 감지 없이 마우스가 없는 모니터를 직접 어둡게 |
| **끄기** | 비활성화 |
| **어둠 강도** | 70 ~ 100% 선택 |
| **재생 멈추면 자동으로 밝게** | 켜면 일시정지 시 바로 밝아짐 (기본 꺼짐) |

## 동작 원리

"전체화면 영상"을 두 신호의 조합으로 판정합니다 — 화면을 꽉 채운 윈도우(전체화면)와, 그 화면에서 영상이 재생 중이라는 신호입니다.

- **전체화면 감지**: `CGWindowList` 로 화면(메뉴바 영역까지)을 덮은 일반 앱 윈도우를 찾습니다. 일반 최대화 창은 메뉴바 아래에서 시작하므로 구별되고, 맥북 노치 디스플레이는 메뉴바 높이(`safeAreaInsets`)를 보정합니다.
- **영상 판정**:
  - 영상 플레이어(IINA·QuickTime·VLC 등)는 **앱 이름**으로 인식합니다.
  - 브라우저·PWA(YouTube·Disney+ 등)는 영상 재생 시 시스템에 거는 **디스플레이 sleep 방지 assertion**(`IOPMCopyAssertionsByProcess`)으로 인식합니다. PWA는 윈도우 프로세스와 assertion 프로세스가 분리되어 있어, PID 매칭 대신 두 신호를 각각 디바운스해 결합합니다.
- **오버레이**: 각 모니터를 덮는 `borderless` 검은 윈도우를 전체화면 Space 위에도 띄우고(`fullScreenAuxiliary`), 클릭은 통과시킵니다.

### 지원 영상 플레이어

IINA · QuickTime Player · VLC · mpv · Movist / Movist Pro · Infuse · Elmedia Player · PotPlayer
그리고 영상 재생 신호를 거는 모든 브라우저·PWA (Chrome · Safari · YouTube · Disney+ 등).

> 목록에 없는 플레이어를 추가하려면 `DimController.swift` 의 `videoPlayers` 에 앱 이름을 넣으면 됩니다.

## 요구 사항

- macOS 13 (Ventura) 이상
- Swift 6.0 toolchain (Xcode 16+)

## 프로젝트 구조

```
Sources/FocusPlay/
├── main.swift              # 앱 진입점 (.accessory 정책 = 메뉴바 전용)
├── AppDelegate.swift       # 메뉴바 UI
├── DimController.swift     # 폴링·신호 결합·오버레이 dim 제어
├── FullscreenDetector.swift# 전체화면 + 영상 재생 신호 수집
├── OverlayWindow.swift     # 모니터를 덮는 검은 오버레이 윈도우
├── Localization.swift      # 로컬라이즈 문자열 헬퍼
└── Resources/<lang>.lproj/ # 6개 언어 문자열
```

## 후원

이 앱이 마음에 드신다면 커피 한 잔으로 응원해 주세요 ☕

<a href="https://www.buymeacoffee.com/typ0s2d10" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/arial-yellow.png" alt="Buy Me A Coffee" height="50"></a>
