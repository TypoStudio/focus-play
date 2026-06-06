<p align="center">
  <img src="assets/title.png" alt="FocusPlay" width="100%">
</p>

<p align="center">
  <b>한국어</b> · <a href="README.en.md">English</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013+-0a84ff?style=flat-square&logo=apple&logoColor=white" alt="platform">
  <img src="https://img.shields.io/badge/Swift-6.0-f05138?style=flat-square&logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/menu%20bar%20app-7c8cf8?style=flat-square" alt="menu bar app">
  <img src="https://img.shields.io/badge/SwiftPM-build-brightgreen?style=flat-square&logo=swift&logoColor=white" alt="SwiftPM">
  <img src="https://img.shields.io/badge/permissions-none-success?style=flat-square" alt="no permissions">
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
