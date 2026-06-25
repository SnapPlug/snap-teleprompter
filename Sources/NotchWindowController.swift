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
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        win.contentView = NSHostingView(
            rootView: TeleprompterOverlay(vm: vm)
                .frame(width: panelW, height: totalH)
        )
        win.orderFrontRegardless()
        self.window = win
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

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}
