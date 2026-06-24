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

    var body: some View {
        ZStack {
            Color.black

            if vm.scriptLines.isEmpty {
                Text("▶ 시작을 누르면 여기에 대본이 흐릅니다")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
            } else {
                scrollingText
            }

            // Bottom fade — text enters smoothly from below
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 24)
            }

            // Top fade — text exits smoothly into the notch
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 20)
                Spacer()
            }

            // Status indicator: green dot while running, pause icon while paused
            VStack {
                HStack {
                    Spacer()
                    if vm.isRunning {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                            .padding(8)
                    } else if !vm.scriptLines.isEmpty {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(8)
                    }
                }
                Spacer()
            }
        }
        .clipShape(BottomRoundedRect(radius: 14))
        // Tap to pause / resume
        .onTapGesture {
            guard !vm.scriptLines.isEmpty else { return }
            vm.togglePause()
        }
    }

    // VStack with vertical offset — SwiftUI handles text wrapping natively,
    // no Canvas clipping risk.
    private var scrollingText: some View {
        GeometryReader { geo in
            VStack(alignment: .center, spacing: vm.lineHeight - CGFloat(vm.fontSize)) {
                ForEach(Array(vm.scriptLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: CGFloat(vm.fontSize), weight: .medium))
                        .foregroundColor(.white)
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
}
