# Snap Teleprompter

맥북 노치 영역에 대본을 흘려보내는 텔레프롬프터 앱입니다.

카메라를 바라보면서 자연스럽게 대본을 읽을 수 있도록, 화면 상단 노치 바로 아래에 텍스트를 스크롤합니다. 녹화 중인 다른 앱의 키보드 포커스를 빼앗지 않습니다.

---

## 요구 사항

- **macOS 13.0 이상** (Ventura 이상 필요 — iMac 2017 등 macOS 12 이하 기기는 미지원)
- 노치가 있는 맥북 (MacBook Pro 2021년 이후, MacBook Air M2 이후)

---

## 설치 및 빌드

### 방법 1 — Command Line Tools만으로 빌드 (Xcode.app 불필요)

Xcode.app 없이 **Command Line Tools**(`swiftc`)만 설치되어 있으면 빌드할 수 있습니다.

**Command Line Tools 설치 확인:**
```bash
xcode-select --install   # 이미 설치되어 있으면 "already installed" 메시지
```

**빌드 및 실행:**
```bash
git clone https://github.com/SnapPlug/snap-teleprompter.git
cd snap-teleprompter
bash build.sh
open SnapTeleprompter.app
```

> 처음 실행 시 Gatekeeper 경고가 뜨면 Finder에서 앱을 **우클릭 → 열기 → 열기**로 실행합니다.

---

### 방법 2 — Xcode로 빌드

```bash
git clone https://github.com/SnapPlug/snap-teleprompter.git
cd snap-teleprompter
open SnapTeleprompter.xcodeproj
```

Xcode에서 **Run** (⌘R) 하면 바로 실행됩니다.

### 방법 3 — XcodeGen 사용 (프로젝트 파일을 직접 수정하고 싶을 때)

`project.yml`을 수정한 뒤 `.xcodeproj`를 재생성할 때 사용합니다.

```bash
brew install xcodegen
xcodegen generate
open SnapTeleprompter.xcodeproj
```

---

## 사용법

### 1. 대본 입력

- 텍스트 편집기에 직접 타이핑하거나
- **파일 열기** 버튼으로 `.txt` 또는 `.md` 파일을 불러옵니다 (Markdown은 자동으로 서식이 제거됩니다)

### 2. 노치에 표시

**노치에 표시** 버튼을 누르면 화면 상단 노치 아래에 오버레이 창이 열립니다.

### 3. 재생

| 동작 | 방법 |
|---|---|
| 재생 / 일시정지 | `Space` 키 또는 노치 패널 탭 |
| 정지 | 정지(■) 버튼 |
| 빨리 감기 / 되감기 | 노치 패널 위에서 스크롤 |
| 속도 올리기 | `>` 키 |
| 속도 낮추기 | `<` 키 |

> `<` / `>` 키는 다른 앱이 포커스를 가지고 있을 때도 작동합니다 (Input Monitoring 권한 필요).

### 4. 속도와 글자 크기

하단 슬라이더로 실시간 조절합니다.

- **속도**: 20 ~ 280 WPM
- **글자 크기**: 10 ~ 22pt

### 상태 표시

노치 패널 오른쪽 상단의 아이콘으로 상태를 확인합니다.

- 초록 점 → 재생 중
- ⏸ 아이콘 → 일시정지

---

## Free vs Pro

| 기능 | Free | Pro |
|------|:----:|:---:|
| **기본** | | |
| 대본 직접 입력 | ✅ | ✅ |
| .txt / .md 파일 불러오기 | ✅ | ✅ |
| 맥북 노치 오버레이 표시 | ✅ | ✅ |
| **재생 제어** | | |
| 재생 / 일시정지 / 정지 | ✅ | ✅ |
| 속도 조절 (20~280 WPM) | ✅ | ✅ |
| 글자 크기 조절 (10~22pt) | ✅ | ✅ |
| 노치 탭으로 일시정지/재개 | ✅ | ✅ |
| 스크롤로 위치 이동 | ✅ | ✅ |
| 키보드 단축키 `Space` / `<` / `>` | ✅ | ✅ |
| **편의 기능** | | |
| 문장 단위 줄바꿈 | ✅ | ✅ |
| 예상 발표 시간 표시 | ✅ | ✅ |
| 발표 타이머 (MM:SS) | ✅ | ✅ |
| 배경색 선택 (검정/흰색) | ✅ | ✅ |
| 노치 크기 조절 | ✅ | ✅ |
| 화면 공유 숨김 (Zoom/Teams) | ✅ | ✅ |
| **발표 현장 기능** | | |
| 폰 리모컨 (브라우저 기반, WiFi) | — | ✅ |
| PDF 발표 자료 연동 | — | ✅ |
| 슬라이드 페이지 마커 | — | ✅ |
| 슬라이드 자동 넘김 | — | ✅ |
| **가격** | 무료 | $7.99 (일회성) |

> Pro는 현재 개발 중입니다. 출시 알림을 받으려면 GitHub에서 ★ Star를 눌러주세요.

---

## 프로젝트 구조

```
Sources/
├── SnapTeleprompterApp.swift    # 앱 진입점
├── MainView.swift               # 메인 UI (대본 편집기 + 컨트롤)
├── TeleprompterViewModel.swift  # 재생 상태, 키보드/스크롤 이벤트, 텍스트 줄바꿈
├── TeleprompterOverlay.swift    # 노치 오버레이 뷰 (스크롤 텍스트)
└── NotchWindowController.swift  # 노치 위치에 floating 윈도우 배치
```

---

## Release Notes

### v1.3.0 — 2026-06-27
- **화면 공유 숨김**: 노치 텔레프롬프터가 Zoom · Teams · Google Meet · 화면 녹화에 캡처되지 않음. 발표자 화면에만 보이고 상대방에게는 보이지 않음 (기본값: 켜짐). 연습 녹화 시 끌 수 있음

### v1.2.0 — 2026-06-26
- **발표 타이머**: 재생 시작부터 경과 시간을 노치 좌하단에 `MM:SS` 표시. 일시정지 시 멈춤, 재개 시 이어서 진행
- **배경색 선택**: 노치 배경을 검정 / 흰색으로 전환. 설정은 앱 재시작 후에도 유지
- **노치 크기 조절**: 패널 너비(280~600px) · 높이(60~220px)를 슬라이더로 실시간 조절. 노치가 열린 상태에서 즉시 반영

### v1.1.0 — 2026-06-25
- **줄바꿈 개선**: 문장 종결 부호(`.` `?` `!` `。` `？` `！`) 기준으로 먼저 분리한 뒤 CoreText로 너비 보정. 문장 중간에서 끊기는 현상 감소
- **예상 발표 시간**: 하단 컨트롤 바에 `예상 발표 시간: 약 N분 M초` 표시. WPM 슬라이더 조작 시 즉시 갱신
- **최저 속도 하향**: 최소 WPM 60 → 20으로 조정

### v1.0.0 — 2026-06-24
- 최초 공개 릴리즈
- 맥북 노치 오버레이 텔레프롬프터 (SwiftUI)
- .txt / .md 파일 불러오기 (Markdown 자동 제거)
- 재생 / 일시정지 / 정지 / 속도 조절 / 글자 크기 조절
- `Space` / `<` / `>` 키보드 단축키 (전역 포함)
- 노치 패널 탭으로 일시정지, 스크롤로 위치 이동
- Command Line Tools(`swiftc`)만으로 빌드 가능
- 앱 아이콘 (Bradley Hand Bold S)
- 노치 내 × 종료 버튼

---

## 라이선스

MIT
