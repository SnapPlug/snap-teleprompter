import AppKit
import SwiftUI

// Custom window that receives mouse clicks without stealing keyboard focus
// from whatever app the user is actively recording with.
private final class NotchOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class NotchWindowController {
    var window: NSWindow?
    private let vm: TeleprompterViewModel
    private var keepFrontTimer: Timer?

    init(vm: TeleprompterViewModel) {
        self.vm = vm
    }

    func show() {
        guard let screen = NSScreen.main else { return }

        let menuBarH: CGFloat = screen.safeAreaInsets.top > 0
            ? screen.safeAreaInsets.top
            : NSStatusBar.system.thickness

        let panelW = vm.panelWidth
        let panelH = vm.panelHeight
        let totalH = menuBarH + panelH
        vm.windowHeight = totalH

        let x = (screen.frame.width - panelW) / 2
        let y = screen.frame.maxY - totalH

        let win = NotchOverlayWindow(
            contentRect: NSRect(x: x, y: y, width: panelW, height: totalH),
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        win.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.ignoresMouseEvents = false
        // .stationary 제거 — full-screen Space 전환 시 새 Space를 따라가지 못하는 원인
        // .canJoinAllSpaces + .fullScreenAuxiliary 조합으로 모든 Space에 진입
        win.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
        win.sharingType = vm.hideFromScreenShare ? .none : .readWrite

        win.contentView = NSHostingView(
            rootView: TeleprompterOverlay(vm: vm)
                .frame(width: panelW, height: totalH)
        )
        win.orderFrontRegardless()
        self.window = win

        // Timer(timeInterval:) + RunLoop.main.add 패턴 사용:
        // scheduledTimer는 .default 모드로 자동 등록되므로 이중 등록 방지를 위해 이 방식 사용.
        // .common 모드 = 트랙패드 스크롤/드래그 중에도 타이머가 멈추지 않음.
        // MainActor.assumeIsolated = Task 없이 동기 호출 → 애니메이션 중 지연 없음.
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.window?.orderFrontRegardless()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        keepFrontTimer = timer
    }

    func resize() {
        guard let screen = NSScreen.main, let win = window else { return }
        let menuBarH: CGFloat = screen.safeAreaInsets.top > 0
            ? screen.safeAreaInsets.top
            : NSStatusBar.system.thickness
        let panelW = vm.panelWidth
        let panelH = vm.panelHeight
        let totalH = menuBarH + panelH
        vm.windowHeight = totalH
        let x = (screen.frame.width - panelW) / 2
        let y = screen.frame.maxY - totalH
        win.setFrame(NSRect(x: x, y: y, width: panelW, height: totalH), display: true, animate: false)
        win.contentView = NSHostingView(
            rootView: TeleprompterOverlay(vm: vm)
                .frame(width: panelW, height: totalH)
        )
    }

    func updateSharingType() {
        window?.sharingType = vm.hideFromScreenShare ? .none : .readWrite
    }

    func hide() {
        keepFrontTimer?.invalidate()
        keepFrontTimer = nil
        window?.orderOut(nil)
        window = nil
    }
}
