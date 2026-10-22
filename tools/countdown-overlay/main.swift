// 카운트다운 오버레이
// 실행하면 시간 설정 창이 뜨고, 시작을 누르면 모든 앱(파워포인트 슬라이드쇼, 전체 화면 브라우저) 위에
// 반투명 작은 시계가 떠서 남은 시간을 보여 준다. 0이 되면 빨간 00:00으로 멈춘다.
// 시계 조작: 드래그로 이동, 마우스를 올리면 뜨는 X로 종료, 우클릭 메뉴(일시정지, 처음부터, 시간 다시 설정, 종료).

import AppKit

// MARK: - 시간 형식

func parseDuration(_ text: String) -> TimeInterval? {
    let t = text.trimmingCharacters(in: .whitespaces)
    if t.contains(":") {
        let parts = t.split(separator: ":").map { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2, let m = parts[0], let s = parts[1], m >= 0, s >= 0, s < 60 else { return nil }
        let total = m * 60 + s
        return total > 0 ? total : nil
    }
    guard let m = Double(t), m > 0 else { return nil }
    return m * 60
}

func formatRemaining(_ seconds: TimeInterval) -> String {
    let total = Int(ceil(max(0, seconds)))
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
}

// MARK: - 오버레이 시계

// 비활성 패널에서도 첫 클릭을 바로 받는 버튼
final class FirstClickButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class ClockView: NSView {
    let label = NSTextField(labelWithString: "00:00")
    let closeButton = FirstClickButton()
    var menuProvider: (() -> NSMenu)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.backgroundColor = NSColor(white: 0, alpha: 0.45).cgColor
        label.font = .monospacedDigitSystemFont(ofSize: 34, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // 마우스를 올렸을 때만 보이는 종료 버튼
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "종료")?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .semibold))
        closeButton.isBordered = false
        closeButton.contentTintColor = NSColor(white: 1, alpha: 0.9)
        closeButton.target = NSApp
        closeButton.action = #selector(NSApplication.terminate(_:))
        closeButton.toolTip = "종료"
        closeButton.isHidden = true
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { closeButton.isHidden = false }
    override func mouseExited(with event: NSEvent) { closeButton.isHidden = true }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menuProvider?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        // 호버 이벤트를 놓쳐 X가 숨어 있어도 그 자리를 누르면 종료한다
        if closeButton.frame.insetBy(dx: -4, dy: -4).contains(convert(event.locationInWindow, from: nil)) {
            NSApp.terminate(nil)
            return
        }
        window?.performDrag(with: event)
    }
}

final class OverlayPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 150, height: 60),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // 파워포인트 슬라이드쇼 같은 전체 화면 위에도 보이도록 높은 레벨 + 모든 스페이스 참여
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - 앱

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextFieldDelegate {
    var setupWindow: NSWindow!
    var minutesField: NSTextField!
    var errorLabel: NSTextField!

    var panel: OverlayPanel?
    var clock: ClockView?
    var timer: Timer?

    var duration: TimeInterval = 180
    var endDate = Date()
    var pausedRemaining: TimeInterval?   // nil이면 진행 중
    var finished = false

    let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
        showSetup()
    }

    // 이미 실행 중일 때 바로가기를 다시 누르면 설정 창을 띄운다
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if setupWindow?.isVisible != true { resetupPressed() }
        return false
    }

    // 시계가 떠 있지 않은 상태에서 설정 창을 닫으면 앱을 끝낸다
    func windowWillClose(_ notification: Notification) {
        if panel?.isVisible != true { NSApp.terminate(nil) }
    }

    // 메뉴 막대 (⌘Q, 붙여넣기 등 기본 단축키용)
    func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "카운트다운 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let editMenu = NSMenu(title: "편집")
        editMenu.addItem(withTitle: "잘라내기", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "복사", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "붙여넣기", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "모두 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        NSApp.mainMenu = main
    }

    // MARK: 설정 창

    let defaultSeconds = 180
    let stepSeconds = 60
    let maxSeconds = 99 * 60 + 59

    func formatSetting(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func showSetup() {
        NSApp.setActivationPolicy(.regular)
        if setupWindow == nil { buildSetupWindow() }
        minutesField.stringValue = formatSetting(defaultSeconds)
        errorLabel.stringValue = ""
        setupWindow.center()
        setupWindow.makeKeyAndOrderFront(nil)
        NSApp.activate()
        setupWindow.makeFirstResponder(minutesField)
        minutesField.selectText(nil)
    }

    func buildSetupWindow() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 230),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "카운트다운"
        w.isReleasedWhenClosed = false
        w.delegate = self
        // 다른 데스크톱(스페이스)이나 전체 화면 앱 위에서 실행해도 지금 보고 있는 화면에 뜨게 한다
        w.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        w.level = .floating

        let title = NSTextField(labelWithString: "카운트다운 시간")
        title.font = .systemFont(ofSize: 15, weight: .semibold)

        minutesField = NSTextField(string: formatSetting(defaultSeconds))
        minutesField.font = .monospacedDigitSystemFont(ofSize: 30, weight: .medium)
        minutesField.alignment = .center
        minutesField.delegate = self
        // 입력칸에는 action을 걸지 않는다. 걸면 창이 포커스를 잃을 때(편집 종료) 저절로 시작된다.
        // Enter는 Start 버튼의 기본 키로 처리한다.
        minutesField.widthAnchor.constraint(equalToConstant: 130).isActive = true

        func stepButton(_ symbol: String, _ label: String, _ action: Selector) -> NSButton {
            let b = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: label)!,
                             target: self, action: action)
            b.bezelStyle = .circular
            b.controlSize = .large
            b.toolTip = label
            return b
        }
        let minus = stepButton("minus", "1분 줄이기", #selector(decrementPressed))
        let plus = stepButton("plus", "1분 늘리기", #selector(incrementPressed))
        let inputRow = NSStackView(views: [minus, minutesField, plus])
        inputRow.spacing = 10

        let presets = NSStackView(views: [1, 3, 5, 10, 15].map { m in
            let b = NSButton(title: "\(m)분", target: self, action: #selector(presetPressed(_:)))
            b.tag = m
            b.bezelStyle = .rounded
            b.controlSize = .small
            return b
        })
        presets.spacing = 4

        let hint = NSTextField(labelWithString: "−/+ 또는 ↑↓ 키로 1분씩. 2:30처럼 직접 적어도 됩니다")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        errorLabel = NSTextField(labelWithString: "")
        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.textColor = .systemRed

        let start = NSButton(title: "Start", target: self, action: #selector(startPressed))
        start.bezelStyle = .rounded
        start.keyEquivalent = "\r"
        start.controlSize = .large
        start.widthAnchor.constraint(equalToConstant: 120).isActive = true

        let stack = NSStackView(views: [title, inputRow, presets, hint, errorLabel, start])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(4, after: hint)
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 16, bottom: 18, right: 16)
        w.contentView = stack
        setupWindow = w
    }

    // 입력칸에 적힌 값(초). 읽을 수 없으면 nil
    func currentSetting() -> Int? {
        parseDuration(minutesField.stringValue).map { Int($0.rounded()) }
    }

    func setSetting(_ seconds: Int) {
        minutesField.stringValue = formatSetting(min(max(seconds, 1), maxSeconds))
        errorLabel.stringValue = ""
        minutesField.currentEditor()?.selectedRange = NSRange(location: minutesField.stringValue.count, length: 0)
    }

    @objc func incrementPressed() {
        setSetting((currentSetting() ?? defaultSeconds) + stepSeconds)
    }

    @objc func decrementPressed() {
        let cur = currentSetting() ?? defaultSeconds
        setSetting(cur > stepSeconds ? max(stepSeconds, cur - stepSeconds) : cur)
    }

    @objc func presetPressed(_ sender: NSButton) {
        setSetting(sender.tag * 60)
    }

    // 입력칸에서 ↑↓ 키로 1분씩 조정
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp(_:)): incrementPressed(); return true
        case #selector(NSResponder.moveDown(_:)): decrementPressed(); return true
        default: return false
        }
    }

    @objc func startPressed() {
        guard let secs = currentSetting(), secs <= maxSeconds else {
            errorLabel.stringValue = "시간을 읽을 수 없어요. 예: 3 또는 2:30"
            NSSound.beep()
            return
        }
        duration = TimeInterval(secs)
        setupWindow.orderOut(nil)
        // 독에서 빠지고 포커스를 뺏지 않는 보조 앱으로 전환
        NSApp.setActivationPolicy(.accessory)
        showOverlay()
        restart()
    }

    // MARK: 오버레이

    func showOverlay() {
        if panel == nil {
            let p = OverlayPanel()
            let v = ClockView(frame: p.contentRect(forFrameRect: p.frame))
            v.menuProvider = { [weak self] in self?.contextMenu() ?? NSMenu() }
            p.contentView = v
            panel = p
            clock = v
            if let saved = defaults.string(forKey: "overlayOrigin") {
                p.setFrameOrigin(NSPointFromString(saved))
            } else if let screen = NSScreen.main {
                let f = screen.visibleFrame
                p.setFrameOrigin(NSPoint(x: f.maxX - p.frame.width - 24, y: f.maxY - p.frame.height - 24))
            }
            NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: p, queue: .main) { [weak self] _ in
                guard let self, let p = self.panel else { return }
                self.defaults.set(NSStringFromPoint(p.frame.origin), forKey: "overlayOrigin")
            }
        }
        panel?.orderFrontRegardless()
    }

    func restart() {
        finished = false
        pausedRemaining = nil
        endDate = Date().addingTimeInterval(duration)
        clock?.layer?.removeAllAnimations()
        timer?.invalidate()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
    }

    func remaining() -> TimeInterval {
        pausedRemaining ?? endDate.timeIntervalSinceNow
    }

    func tick() {
        guard let clock else { return }
        let r = remaining()
        clock.label.stringValue = formatRemaining(r)
        if r <= 0 {
            finish()
        } else if r <= 30 {
            clock.label.textColor = .systemYellow
        } else {
            clock.label.textColor = pausedRemaining == nil ? .white : NSColor(white: 1, alpha: 0.5)
        }
    }

    func finish() {
        guard !finished else { return }
        finished = true
        timer?.invalidate()
        timer = nil
        guard let clock else { return }
        clock.label.stringValue = formatRemaining(0)
        clock.label.textColor = .white
        clock.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.85).cgColor
        // 세 번 깜빡여 끝났음을 알린다
        let blink = CABasicAnimation(keyPath: "opacity")
        blink.fromValue = 1
        blink.toValue = 0.25
        blink.duration = 0.35
        blink.autoreverses = true
        blink.repeatCount = 3
        clock.layer?.add(blink, forKey: "blink")
    }

    func resetClockColor() {
        clock?.layer?.backgroundColor = NSColor(white: 0, alpha: 0.45).cgColor
    }

    // MARK: 우클릭 메뉴

    func contextMenu() -> NSMenu {
        let m = NSMenu()
        if !finished {
            let title = pausedRemaining == nil ? "일시정지" : "계속"
            m.addItem(withTitle: title, action: #selector(togglePause), keyEquivalent: "").target = self
        }
        m.addItem(withTitle: "처음부터 다시 (\(formatRemaining(duration)))", action: #selector(restartPressed), keyEquivalent: "").target = self
        m.addItem(withTitle: "시간 다시 설정…", action: #selector(resetupPressed), keyEquivalent: "").target = self
        m.addItem(.separator())
        m.addItem(withTitle: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        return m
    }

    @objc func togglePause() {
        if let r = pausedRemaining {
            endDate = Date().addingTimeInterval(r)
            pausedRemaining = nil
        } else {
            pausedRemaining = max(0, endDate.timeIntervalSinceNow)
        }
        tick()
    }

    @objc func restartPressed() {
        resetClockColor()
        restart()
    }

    @objc func resetupPressed() {
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        resetClockColor()
        showSetup()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
