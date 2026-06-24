# Notch Teleprompter

맥북 노치 영역에 대본을 흘려보내는 텔레프롬프터 앱입니다.

카메라를 바라보면서 자연스럽게 대본을 읽을 수 있도록, 화면 상단 노치 바로 아래에 텍스트를 스크롤합니다. 녹화 중인 다른 앱의 키보드 포커스를 빼앗지 않습니다.

---

## 요구 사항

- macOS 13.0 이상
- 노치가 있는 맥북 (MacBook Pro 2021년 이후, MacBook Air M2 이후)
- Xcode 16.0 ([Mac App Store에서 무료 설치](https://apps.apple.com/kr/app/xcode/id497799835))

---

## 설치 및 빌드

### 방법 1 — Xcode만 사용 (권장)

```bash
git clone https://github.com/SnapPlug/snap-teleprompter.git
cd snap-teleprompter
open NotchTeleprompter.xcodeproj
```

Xcode에서 **Run** (⌘R) 하면 바로 실행됩니다.

### 방법 2 — XcodeGen 사용 (프로젝트 파일을 직접 수정하고 싶을 때)

`project.yml`을 수정한 뒤 `.xcodeproj`를 재생성할 때 사용합니다.

```bash
brew install xcodegen
xcodegen generate
open NotchTeleprompter.xcodeproj
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

- **속도**: 60 ~ 280 WPM
- **글자 크기**: 10 ~ 22pt

### 상태 표시

노치 패널 오른쪽 상단의 아이콘으로 상태를 확인합니다.

- 초록 점 → 재생 중
- ⏸ 아이콘 → 일시정지

---

## 프로젝트 구조

```
Sources/
├── NotchTeleprompterApp.swift   # 앱 진입점
├── MainView.swift               # 메인 UI (대본 편집기 + 컨트롤)
├── TeleprompterViewModel.swift  # 재생 상태, 키보드/스크롤 이벤트, 텍스트 줄바꿈
├── TeleprompterOverlay.swift    # 노치 오버레이 뷰 (스크롤 텍스트)
└── NotchWindowController.swift  # 노치 위치에 floating 윈도우 배치
```

---

## 라이선스

MIT
