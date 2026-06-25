import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @ObservedObject var vm: TeleprompterViewModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ZStack(alignment: .topLeading) {
                TextEditor(text: $vm.scriptText)
                    .font(.system(size: 15, design: .serif))
                    .padding(12)

                if vm.scriptText.isEmpty {
                    Text("대본을 여기에 입력하거나 .txt / .md 파일을 불러오세요…")
                        .font(.system(size: 15, design: .serif))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }

            Divider()

            controls
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))

            Divider()

            displaySettings
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.topthird.inset.filled")
                .font(.title2)
                .foregroundColor(.primary)
            Text("Snap Teleprompter")
                .font(.headline)

            Spacer()

            Button(action: openFile) {
                Label("파일 열기", systemImage: "doc.text")
            }
            .buttonStyle(.bordered)

            Button(action: vm.toggleNotch) {
                Label(
                    vm.notchVisible ? "노치 닫기" : "노치에 표시",
                    systemImage: vm.notchVisible ? "xmark.circle" : "macwindow.badge.plus"
                )
            }
            .buttonStyle(.bordered)
            .tint(vm.notchVisible ? .red : .accentColor)

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("종료", systemImage: "power")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 24) {
            sliderControl(
                label: "속도",
                value: $vm.wordsPerMinute,
                range: 20...280,
                display: "\(Int(vm.wordsPerMinute)) WPM",
                width: 150
            )

            sliderControl(
                label: "글자 크기",
                value: $vm.fontSize,
                range: 10...22,
                display: "\(Int(vm.fontSize))pt",
                width: 110
            )

            if !vm.estimatedDuration.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("예상 발표 시간")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(vm.estimatedDuration)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }

            Spacer()

            playbackButtons
        }
    }

    // MARK: - Display Settings (P2 + P3)

    private var displaySettings: some View {
        HStack(spacing: 20) {
            // P2: background color
            VStack(alignment: .leading, spacing: 3) {
                Text("배경색")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 6) {
                    Button(action: { vm.isDarkBackground = true }) {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle().strokeBorder(vm.isDarkBackground ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: { vm.isDarkBackground = false }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle().strokeBorder(vm.isDarkBackground ? Color.gray.opacity(0.3) : Color.accentColor, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().frame(height: 28)

            // P3: panel width
            VStack(alignment: .leading, spacing: 3) {
                Text("패널 너비: \(Int(vm.panelWidth))px")
                    .font(.caption).foregroundColor(.secondary)
                Slider(value: $vm.panelWidth, in: 280...600)
                    .frame(width: 110)
            }

            // P3: panel height
            VStack(alignment: .leading, spacing: 3) {
                Text("패널 높이: \(Int(vm.panelHeight))px")
                    .font(.caption).foregroundColor(.secondary)
                Slider(value: $vm.panelHeight, in: 60...220)
                    .frame(width: 110)
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private func sliderControl(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        display: String,
        width: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(label): \(display)")
                .font(.caption)
                .foregroundColor(.secondary)
            Slider(value: value, in: range)
                .frame(width: width)
        }
    }

    private var playbackButtons: some View {
        HStack(spacing: 8) {
            Button { vm.stop() } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.bordered)
            .disabled(!vm.isRunning && vm.scriptLines.isEmpty)

            Button {
                if vm.scriptLines.isEmpty { vm.start() } else { vm.togglePause() }
            } label: {
                Image(systemName: vm.isRunning ? "pause.fill" : "play.fill")
                    .frame(width: 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.scriptText.isEmpty)
            .keyboardShortcut(.space, modifiers: [])
        }
    }

    // MARK: - File picker

    private func openFile() {
        let panel = NSOpenPanel()
        panel.title = "대본 파일 선택"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        var types: [UTType] = [.plainText]
        if let mdType = UTType(filenameExtension: "md") { types.append(mdType) }
        panel.allowedContentTypes = types

        if panel.runModal() == .OK, let url = panel.url {
            vm.loadFile(url)
        }
    }
}
