import AppKit
import Combine
import CoreText
import SwiftUI

@MainActor
final class TeleprompterViewModel: ObservableObject {
    // Script
    @Published var scriptText: String = ""
    @Published var scriptLines: [String] = []  // pre-wrapped to panel width

    // Playback
    @Published var isRunning = false
    @Published var wordsPerMinute: Double = 130
    @Published var fontSize: Double = 14

    // Vertical scroll offset
    @Published var verticalOffset: CGFloat = 0

    // Notch overlay
    private var notchController: NotchWindowController?
    @Published var notchVisible = false

    private var displayLink: AnyCancellable?
    private var lastTimestamp: CFTimeInterval = 0
    private var cancellables = Set<AnyCancellable>()

    // Key monitors — both managed here so VM owns all state
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var scrollMonitor: Any?

    // Panel dimensions — kept in sync with NotchWindowController
    let panelWidth: CGFloat = 340
    let panelHeight: CGFloat = 110

    // Total window height including menu bar (set by NotchWindowController)
    var windowHeight: CGFloat = 147

    init() {
        // Re-wrap lines whenever script is edited while the notch is open
        $scriptText
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.notchVisible else { return }
                self.scriptLines = self.wrapScript(self.scriptText, maxWidth: self.panelWidth - 40)
            }
            .store(in: &cancellables)
    }

    var lineHeight: CGFloat { CGFloat(fontSize) * 1.65 }

    var pixelsPerSecond: CGFloat {
        CGFloat(wordsPerMinute) * 0.27
    }

    // MARK: - Speed control (keyboard < >)

    func increaseSpeed() {
        wordsPerMinute = min(280, wordsPerMinute + 10)
    }

    func decreaseSpeed() {
        wordsPerMinute = max(20, wordsPerMinute - 10)
    }

    // MARK: - File loading

    func loadFile(_ url: URL) {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return }
        scriptText = url.pathExtension.lowercased() == "md" ? stripMarkdown(raw) : raw
    }

    // MARK: - Notch window

    func toggleNotch() {
        if notchVisible {
            notchController?.hide()
            notchController = nil
            notchVisible = false
            stopKeyMonitoring()
        } else {
            let controller = NotchWindowController(vm: self)
            controller.show()
            notchController = controller
            notchVisible = true
            startKeyMonitoring()
        }
    }

    // MARK: - Key monitoring

    private func startKeyMonitoring() {
        // Local monitor: fires inside our own app. Returns nil to CONSUME the event
        // so < / > never reach the TextEditor while the notch is active.
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let chars = event.characters else { return event }
            switch chars {
            case "<":
                self.decreaseSpeed()
                return nil  // consumed — TextEditor never sees it
            case ">":
                self.increaseSpeed()
                return nil
            default:
                return event
            }
        }

        // Global monitor: fires when another app is key (e.g. camera/recording app).
        // Needs Input Monitoring permission; silently skipped if not granted.
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let chars = event.characters else { return }
            Task { @MainActor [weak self] in
                switch chars {
                case "<": self?.decreaseSpeed()
                case ">": self?.increaseSpeed()
                default: break
                }
            }
        }

        // Scroll wheel on the notch panel → rewind / fast-forward position.
        // Pauses automatically on first scroll so the user can find the right spot,
        // then taps the panel to resume.
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self,
                  let notchWin = self.notchController?.window,
                  event.window === notchWin else { return event }

            let delta = event.hasPreciseScrollingDeltas
                ? event.scrollingDeltaY          // trackpad: pixel-precise
                : event.scrollingDeltaY * 12     // mouse wheel: scale up

            guard abs(delta) > 0.5 else { return nil }

            // Pause on first scroll so the position stays stable while seeking
            if self.isRunning { self.togglePause() }

            let maxOffset = self.windowHeight + 10
            let minOffset = -(CGFloat(self.scriptLines.count) * self.lineHeight + 20)
            self.verticalOffset = max(minOffset, min(maxOffset, self.verticalOffset + delta))
            return nil  // consumed — notch window has no scroll view
        }
    }

    private func stopKeyMonitoring() {
        if let m = localKeyMonitor  { NSEvent.removeMonitor(m); localKeyMonitor  = nil }
        if let m = globalKeyMonitor { NSEvent.removeMonitor(m); globalKeyMonitor = nil }
        if let m = scrollMonitor    { NSEvent.removeMonitor(m); scrollMonitor    = nil }
    }

    // MARK: - Playback

    func start() {
        guard !scriptText.isEmpty else { return }
        // Pre-wrap text to panel width so Canvas never clips
        let usableWidth = panelWidth - 40
        scriptLines = wrapScript(scriptText, maxWidth: usableWidth)
        verticalOffset = windowHeight + 10
        isRunning = true
        startTicker()
    }

    func togglePause() {
        isRunning.toggle()
        if isRunning { startTicker() } else { stopTicker() }
    }

    func stop() {
        isRunning = false
        stopTicker()
        verticalOffset = windowHeight + 10
        scriptLines = []
    }

    // MARK: - Animation

    private func startTicker() {
        lastTimestamp = CACurrentMediaTime()
        displayLink = Timer
            .publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.tick() }
            }
    }

    private func stopTicker() {
        displayLink?.cancel()
        displayLink = nil
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = CGFloat(now - lastTimestamp)
        lastTimestamp = now
        verticalOffset -= pixelsPerSecond * dt
        let totalHeight = CGFloat(scriptLines.count) * lineHeight
        if verticalOffset < -(totalHeight + windowHeight) {
            isRunning = false
            stopTicker()
        }
    }

    // MARK: - Text pre-wrapping (CoreText)

    private func wrapScript(_ text: String, maxWidth: CGFloat) -> [String] {
        let paragraphs = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return paragraphs.flatMap { wrapParagraph($0, maxWidth: maxWidth) }
    }

    private func wrapParagraph(_ text: String, maxWidth: CGFloat) -> [String] {
        let nsFont = NSFont.systemFont(ofSize: CGFloat(fontSize), weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: nsFont]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let setter = CTFramesetterCreateWithAttributedString(attrStr)

        // Give a generous height so all lines are captured
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: maxWidth, height: 100_000), transform: nil)
        let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil)
        guard let ctLines = CTFrameGetLines(frame) as? [CTLine] else { return [text] }

        let nsText = text as NSString
        return ctLines.compactMap { line -> String? in
            let r = CTLineGetStringRange(line)
            guard r.length > 0 else { return nil }
            let s = nsText.substring(with: NSRange(location: r.location, length: r.length))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : s
        }
    }

    // MARK: - Markdown stripping

    private func stripMarkdown(_ text: String) -> String {
        var t = text
        t = t.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "`[^`]+`", with: "", options: .regularExpression)
        let lines = t.components(separatedBy: .newlines).map { line -> String in
            var l = line
            for pattern in ["^#{1,6}\\s+", "^>+\\s?", "^[-*+]\\s+", "^\\d+\\.\\s+"] {
                if let r = l.range(of: pattern, options: .regularExpression) { l.removeSubrange(r) }
            }
            return l
        }
        t = lines.joined(separator: "\n")
        t = t.replacingOccurrences(of: "(\\*{1,3}|_{1,3})(.+?)\\1", with: "$2", options: .regularExpression)
        t = t.replacingOccurrences(of: "!\\[[^\\]]*\\]\\([^)]+\\)", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
