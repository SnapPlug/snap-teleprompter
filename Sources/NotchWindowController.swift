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
    private var spaceObserver: Any?

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
        // fullScreenAuxiliary — 전체화면 Space에도 진입
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        win.sharingType = vm.hideFromScreenShare ? .none : .readWrite

        win.contentView = NSHostingView(
            rootView: TeleprompterOverlay(vm: vm)
                .frame(width: panelW, height: totalH)
        )
        win.orderFrontRegardless()
        self.window = win

        // 전체화면 전환 등 Space가 바뀔 때마다 최상단으로 다시 올림
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.window?.orderFrontRegardless()
            }
        }
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
        if let obs = spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            spaceObserver = nil
        }
        window?.orderOut(nil)
        window = nil
    }
}
