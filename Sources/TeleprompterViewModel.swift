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

    // Panel dimensions — user can resize (P3)
    @Published var panelWidth: CGFloat = {
        let v = UserDefaults.standard.double(forKey: "panelWidth")
        return v > 0 ? CGFloat(v) : 340
    }()
    @Published var panelHeight: CGFloat = {
        let v = UserDefaults.standard.double(forKey: "panelHeight")
        return v > 0 ? CGFloat(v) : 110
    }()

    // Background color toggle (P2)
    @Published var isDarkBackground: Bool = UserDefaults.standard.object(forKey: "isDarkBackground") as? Bool ?? true

    // Screen share privacy — hide notch from Zoom/Teams/recordings (default ON)
    @Published var hideFromScreenShare: Bool = UserDefaults.standard.object(forKey: "hideFromScreenShare") as? Bool ?? true

    // Playback stopped flag — distinguishes "stopped" from "paused" for play button logic
    @Published var isStopped: Bool = false

    // Presentation timer (P1)
    @Published var elapsedSeconds: Int = 0
    private var timerStart: CFTimeInterval = 0
    private var timerAccumulated: CFTimeInterval = 0

    // Total window height including menu bar (set by NotchWindowController)
    var windowHeight: CGFloat = 147

    init() {
        // Re-wrap when script changes while notch is open
        $scriptText
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.notchVisible else { return }
                self.scriptLines = self.wrapScript(self.scriptText, maxWidth: self.panelWidth - 40)
            }
            .store(in: &cancellables)

        // P3: resize notch and re-wrap when panel width changes
        $panelWidth
            .dropFirst()
            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
            .sink { [weak self] newWidth in
                guard let self else { return }
                UserDefaults.standard.set(Double(newWidth), forKey: "panelWidth")
                if self.notchVisible {
                    self.notchController?.resize()
                    self.scriptLines = self.wrapScript(self.scriptText, maxWidth: newWidth - 40)
                }
            }
            .store(in: &cancellables)

        // P3: resize notch when panel height changes
        $panelHeight
            .dropFirst()
            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                UserDefaults.standard.set(Double(self.panelHeight), forKey: "panelHeight")
                if self.notchVisible { self.notchController?.resize() }
            }
            .store(in: &cancellables)

        // P2: persist background color choice
        $isDarkBackground
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: "isDarkBackground") }
            .store(in: &cancellables)

        // Screen share privacy: update window sharingType immediately
        $hideFromScreenShare
            .dropFirst()
            .sink { [weak self] value in
                UserDefaults.standard.set(value, forKey: "hideFromScreenShare")
                self?.notchController?.updateSharingType()
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
        let usableWidth = panelWidth - 40
        scriptLines = wrapScript(scriptText, maxWidth: usableWidth)
        verticalOffset = windowHeight + 10
        elapsedSeconds = 0
        timerAccumulated = 0
        timerStart = CACurrentMediaTime()
        isStopped = false
        isRunning = true
        startTicker()
    }

    func togglePause() {
        if isRunning {
            timerAccumulated += CACurrentMediaTime() - timerStart
            stopTicker()
        } else {
            timerStart = CACurrentMediaTime()
            startTicker()
        }
        isRunning.toggle()
    }

    func stop() {
        isRunning = false
        isStopped = true
        stopTicker()
        verticalOffset = windowHeight + 10
        elapsedSeconds = 0
        timerAccumulated = 0
        // scriptLines 유지 — 오버레이에서 안내 텍스트가 나오지 않도록
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
        elapsedSeconds = Int(timerAccumulated + (now - timerStart))
        let totalHeight = CGFloat(scriptLines.count) * lineHeight
        if verticalOffset < -(totalHeight + windowHeight) {
            isRunning = false
            stopTicker()
        }
    }

    // MARK: - Estimated presentation time (F10)

    var estimatedDuration: String {
        let words = scriptText
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
        guard words > 0 else { return "" }
        let totalSeconds = Int(Double(words) / wordsPerMinute * 60)
        if totalSeconds < 60 {
            return "약 \(totalSeconds)초"
        }
        let min = totalSeconds / 60
        let sec = totalSeconds % 60
        if min >= 60 {
            let hr = min / 60
            let rem = min % 60
            return rem > 0 ? "약 \(hr)시간 \(rem)분" : "약 \(hr)시간"
        }
        return sec > 0 ? "약 \(min)분 \(sec)초" : "약 \(min)분"
    }

    // MARK: - Text pre-wrapping (sentence-aware + CoreText) (F9)

    private func wrapScript(_ text: String, maxWidth: CGFloat) -> [String] {
        text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .flatMap { sentenceAwareWrap($0, maxWidth: maxWidth) }
    }

    // Split a line at sentence boundaries, merge short chunks, then CoreText-wrap
    private func sentenceAwareWrap(_ text: String, maxWidth: CGFloat) -> [String] {
        let sentences = splitAtSentences(text)
        let merged = mergeSentences(sentences, maxWidth: maxWidth)
        return merged.flatMap { wrapParagraph($0, maxWidth: maxWidth) }
    }

    // Break at terminal punctuation followed by whitespace
    private func splitAtSentences(_ text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "(?<=[.!?。？！])\\s+") else {
            return [text]
        }
        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        var parts: [String] = []
        var cursor = 0

        for match in regex.matches(in: text, range: fullRange) {
            let partRange = NSRange(location: cursor, length: match.range.location - cursor)
            let part = ns.substring(with: partRange).trimmingCharacters(in: .whitespaces)
            if !part.isEmpty { parts.append(part) }
            cursor = match.range.location + match.range.length
        }
        let tail = ns.substring(from: cursor).trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { parts.append(tail) }

        return parts.isEmpty ? [text] : parts
    }

    // Merge consecutive short sentences (< 40% of panel width) to avoid sparse lines
    private func mergeSentences(_ sentences: [String], maxWidth: CGFloat) -> [String] {
        let minWidth = maxWidth * 0.4
        var result: [String] = []
        var buffer = ""

        for sentence in sentences {
            if buffer.isEmpty {
                buffer = sentence
            } else if measureTextWidth(buffer) < minWidth {
                buffer += " " + sentence
            } else {
                result.append(buffer)
                buffer = sentence
            }
        }
        if !buffer.isEmpty { result.append(buffer) }
        return result
    }

    private func measureTextWidth(_ text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: CGFloat(fontSize), weight: .medium)
        return (text as NSString).size(withAttributes: [.font: font]).width
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
