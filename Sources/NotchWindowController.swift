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

    // Fires frequently to keep the overlay on top across all Spaces and full-screen transitions.
    // Space swipe animations last ~300ms; 200ms interval ensures < 1 frame of invisibility.
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
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        win.sharingType = vm.hideFromScreenShare ? .none : .readWrite

        win.contentView = NSHostingView(
            rootView: TeleprompterOverlay(vm: vm)
                .frame(width: panelW, height: totalH)
        )
        win.orderFrontRegardless()
        self.window = win

        // Poll at 200ms — covers the ~300ms Space-swipe animation gap.
        // .common mode ensures the timer fires even during trackpad scroll tracking.
        keepFrontTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.window?.orderFrontRegardless() }
        }
        RunLoop.main.add(keepFrontTimer!, forMode: .common)
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
