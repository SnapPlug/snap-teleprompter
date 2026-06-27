import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    featureSection("시작하기", items: startItems)
                    featureSection("재생 제어", items: playbackItems)
                    featureSection("속도 · 크기 · 위치", items: controlItems)
                    featureSection("화면 설정", items: displayItems)
                    featureSection("편의 기능", items: convenienceItems)
                    featureSection(
                        "전역 단축키",
                        items: globalItems,
                        note: "시스템 환경설정 → 개인 정보 보호 및 보안 → 입력 모니터링에서 SnapTeleprompter를 허용해야 합니다."
                    )
                }
                .padding(24)
            }

            Divider()

            footer
        }
        .frame(width: 520, height: 580)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "rectangle.topthird.inset.filled")
                .font(.largeTitle)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text("Snap Teleprompter")
                    .font(.title2.bold())
                Text("맥북 노치에서 대본을 자연스럽게 읽어보세요")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(24)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("닫기") {
                UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Section Builder

    private func featureSection(_ title: String, items: [OnboardItem], note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(items) { item in
                    OnboardRowView(item: item)
                }
            }

            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Content

    private var startItems: [OnboardItem] { [
        OnboardItem(icon: "text.alignleft",
                    title: "대본 입력",
                    desc: "편집기에 직접 타이핑하거나 파일 열기로 .txt / .md 파일을 불러옵니다. Markdown 서식은 자동으로 제거됩니다."),
        OnboardItem(icon: "macwindow.badge.plus",
                    title: "노치에 표시",
                    desc: "\"노치에 표시\" 버튼을 누르면 화면 상단 노치 아래에 오버레이가 열립니다. 다른 앱의 키보드 포커스를 빼앗지 않습니다."),
    ] }

    private var playbackItems: [OnboardItem] { [
        OnboardItem(icon: "play.fill",
                    title: "재생 / 일시정지",
                    desc: "▶ 버튼 또는 Space 키로 토글합니다. 노치가 열려 있으면 Space 키가 작동합니다.",
                    shortcuts: ["Space"]),
        OnboardItem(icon: "stop.fill",
                    title: "정지",
                    desc: "■ 버튼을 누르면 대본을 처음 위치로 초기화합니다."),
        OnboardItem(icon: "hand.tap",
                    title: "노치 탭으로 일시정지 / 재개",
                    desc: "노치 패널을 클릭하면 재생 중에는 일시정지, 멈춘 상태에서는 재개됩니다."),
    ] }

    private var controlItems: [OnboardItem] { [
        OnboardItem(icon: "gauge.with.dots.needle.bottom.50percent",
                    title: "속도 조절",
                    desc: "하단 슬라이더로 20~280 WPM 범위에서 조절합니다. 노치가 열린 상태에서 키보드 단축키도 사용할 수 있습니다.",
                    shortcuts: ["Shift <", "Shift >"]),
        OnboardItem(icon: "textformat.size",
                    title: "글자 크기",
                    desc: "하단 슬라이더로 10~22pt 범위에서 조절합니다."),
        OnboardItem(icon: "scroll",
                    title: "위치 이동",
                    desc: "노치 패널 위에서 스크롤하면 자동으로 일시정지되고 원하는 위치로 이동합니다. 다시 탭하면 재개됩니다."),
    ] }

    private var displayItems: [OnboardItem] { [
        OnboardItem(icon: "circle.lefthalf.filled",
                    title: "배경색",
                    desc: "노치 배경을 검정 / 흰색으로 전환합니다. 선택한 색상은 앱 재시작 후에도 유지됩니다."),
        OnboardItem(icon: "arrow.up.left.and.arrow.down.right",
                    title: "노치 크기",
                    desc: "패널 너비(280~600px)와 높이(60~220px)를 슬라이더로 실시간 조절합니다."),
        OnboardItem(icon: "eye.slash",
                    title: "화면 공유 숨김",
                    desc: "켜짐(기본값)이면 Zoom · Teams · Google Meet 화면 공유 및 화면 녹화에 노치가 캡처되지 않습니다. 연습 녹화 시 끄세요."),
    ] }

    private var convenienceItems: [OnboardItem] { [
        OnboardItem(icon: "clock",
                    title: "예상 발표 시간",
                    desc: "대본 분량과 WPM 설정을 바탕으로 자동 계산됩니다. 속도 슬라이더 조작 시 즉시 업데이트됩니다."),
        OnboardItem(icon: "timer",
                    title: "발표 타이머",
                    desc: "재생이 시작되면 노치 좌하단에 경과 시간(MM:SS)이 표시됩니다. 일시정지 시 멈추고 재개 시 이어집니다."),
    ] }

    private var globalItems: [OnboardItem] { [
        OnboardItem(icon: "command",
                    title: "전역 속도 조절",
                    desc: "Keynote · 카메라 앱 등 다른 앱이 활성화된 상태에서도 속도를 조절할 수 있습니다.",
                    shortcuts: ["Shift <", "Shift >"]),
    ] }
}

// MARK: - Row

struct OnboardItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let desc: String
    var shortcuts: [String] = []
}

struct OnboardRowView: View {
    let item: OnboardItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 20, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                    ForEach(item.shortcuts, id: \.self) { key in
                        KeyBadge(text: key)
                    }
                }
                Text(item.desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Key Badge

struct KeyBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.35), lineWidth: 0.5)
            )
    }
}
