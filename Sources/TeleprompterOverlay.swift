import SwiftUI

struct BottomRoundedRect: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct TeleprompterOverlay: View {
    @ObservedObject var vm: TeleprompterViewModel

    // P2: dynamic colors
    private var bg: Color { vm.isDarkBackground ? .black : .white }
    private var fg: Color { vm.isDarkBackground ? .white : .black }

    var body: some View {
        ZStack {
            bg

            if vm.scriptLines.isEmpty {
                Text("▶ 시작을 누르면 여기에 대본이 흐릅니다")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(fg.opacity(0.35))
            } else {
                scrollingText
            }

            // Bottom fade
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(colors: [.clear, bg], startPoint: .top, endPoint: .bottom)
                    .frame(height: 24)
            }

            // Top fade
            VStack(spacing: 0) {
                LinearGradient(colors: [bg, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 20)
                Spacer()
            }

            // Overlay controls
            VStack {
                HStack {
                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Text("×")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(fg.opacity(0.35))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .padding(6)

                    Spacer()

                    if vm.isRunning {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                            .padding(8)
                    } else if !vm.scriptLines.isEmpty {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 9))
                            .foregroundColor(fg.opacity(0.5))
                            .padding(8)
                    }
                }

                Spacer()

                // P1: presentation timer
                if vm.elapsedSeconds > 0 {
                    HStack {
                        Text(timerLabel)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(fg.opacity(0.3))
                            .padding(.leading, 8)
                            .padding(.bottom, 6)
                        Spacer()
                    }
                }
            }
        }
        .clipShape(BottomRoundedRect(radius: 14))
        .onTapGesture {
            guard !vm.scriptLines.isEmpty else { return }
            vm.togglePause()
        }
    }

    private var scrollingText: some View {
        GeometryReader { geo in
            VStack(alignment: .center, spacing: vm.lineHeight - CGFloat(vm.fontSize)) {
                ForEach(Array(vm.scriptLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: CGFloat(vm.fontSize), weight: .medium))
                        .foregroundColor(fg)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: geo.size.width - 40)
                }
            }
            .frame(width: geo.size.width)
            .offset(y: vm.verticalOffset)
        }
        .clipped()
    }

    // P1: MM:SS or HH:MM:SS
    private var timerLabel: String {
        let s = vm.elapsedSeconds
        if s < 3600 {
            return String(format: "%02d:%02d", s / 60, s % 60)
        }
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}
