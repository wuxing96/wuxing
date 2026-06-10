import AppKit
import TrafficLightCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel!
    private var trafficView: TrafficLightView!
    private var timer: Timer?
    private let store = CodexSessionStore()
    private var isExpanded = false
    private var userMovedWindow = false
    private var isDragging = false
    private var refreshInFlight = false
    private var refreshPending = false
    private var lastTokenRefresh = Date(timeIntervalSince1970: 0)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        trafficView = TrafficLightView(frame: NSRect(origin: .zero, size: Layout.collapsedSize))
        trafficView.onSetExpanded = { [weak self] expanded in
            self?.setExpanded(expanded)
        }
        trafficView.onMove = { [weak self] delta in
            self?.movePanel(by: delta)
        }
        trafficView.onDragStateChange = { [weak self] dragging in
            self?.isDragging = dragging
            if !dragging {
                self?.refresh()
            }
        }
        trafficView.onRequestClose = { [weak self] in
            self?.confirmQuit()
        }
        trafficView.onQuit = { [weak self] in
            self?.confirmQuit()
        }
        trafficView.onResetPosition = { [weak self] in
            self?.resetPanelPosition()
        }

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Layout.collapsedSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = trafficView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        panel.orderFrontRegardless()
        panel.makeFirstResponder(trafficView)

        positionPanel(size: Layout.collapsedSize)
        refresh()

        let timer = Timer(timeInterval: TrafficLightRefreshPolicy.statusInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    private func refresh() {
        guard !isDragging else {
            return
        }
        if refreshInFlight {
            refreshPending = true
            return
        }
        refreshInFlight = true
        refreshPending = false
        let store = self.store
        let now = Date()
        let shouldRefreshTokenUsage = now.timeIntervalSince(lastTokenRefresh) >= TrafficLightRefreshPolicy.tokenUsageInterval
            || trafficView.summary.tokenUsage.updatedAt == nil
        let currentTokenUsage = trafficView.summary.tokenUsage
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let sessions = store.loadSessions(now: now)
            let tokenUsage = shouldRefreshTokenUsage ? store.loadTokenUsage(now: now) : currentTokenUsage
            let summary = SessionAggregator.aggregate(sessions, tokenUsage: tokenUsage)
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.refreshInFlight = false
                if shouldRefreshTokenUsage {
                    self.lastTokenRefresh = now
                }
                guard !self.isDragging else {
                    return
                }
                self.trafficView.summary = summary
                if self.isExpanded {
                    self.resizeExpandedPanel()
                }
                if self.refreshPending {
                    self.refresh()
                }
            }
        }
    }

    private func toggleExpanded() {
        setExpanded(!isExpanded)
    }

    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else {
            return
        }

        isExpanded = expanded
        let size = isExpanded ? expandedSize() : Layout.collapsedSize
        trafficView.mode = isExpanded ? .expanded : .collapsed
        trafficView.setFrameSize(size)
        panel.makeFirstResponder(trafficView)

        if userMovedWindow {
            let oldFrame = panel.frame
            panel.setFrame(
                NSRect(
                    x: oldFrame.maxX - size.width,
                    y: oldFrame.minY,
                    width: size.width,
                    height: size.height
                ),
                display: true,
                animate: true
            )
        } else {
            positionPanel(size: size, animate: true)
        }
    }

    private func resetPanelPosition() {
        userMovedWindow = false
        let size = isExpanded ? expandedSize() : Layout.collapsedSize
        positionPanel(size: size, animate: true)
    }

    private func confirmQuit() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Close \(TrafficLightProduct.displayName)?"
        alert.informativeText = "The status window will stop watching Codex sessions until you launch it again."
        alert.addButton(withTitle: "Close")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }

    private func resizeExpandedPanel() {
        let size = expandedSize()
        guard abs(panel.frame.width - size.width) > 0.5 || abs(panel.frame.height - size.height) > 0.5 else {
            return
        }

        trafficView.setFrameSize(size)
        if userMovedWindow {
            let oldFrame = panel.frame
            panel.setFrame(
                NSRect(
                    x: oldFrame.maxX - size.width,
                    y: oldFrame.minY,
                    width: size.width,
                    height: size.height
                ),
                display: true
            )
        } else {
            positionPanel(size: size)
        }
    }

    private func expandedSize() -> CGSize {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 900
        return Layout.expandedSize(
            sessionCount: trafficView.summary.sessions.count,
            screenHeight: screenHeight
        )
    }

    private func movePanel(by delta: CGPoint) {
        userMovedWindow = true
        var frame = panel.frame
        frame.origin.x += delta.x
        frame.origin.y += delta.y
        panel.setFrame(frame, display: true)
    }

    private func positionPanel(size: CGSize, animate: Bool = false) {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = CGPoint(
            x: screen.maxX - size.width - Layout.screenMargin,
            y: screen.minY + Layout.screenMargin
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: animate)
    }
}

private enum Layout {
    static let collapsedSize = CGSize(width: 214, height: 44)
    static let expandedWidth: CGFloat = 370
    static let minExpandedHeight: CGFloat = 220
    static let expandedHeaderHeight: CGFloat = 94
    static let rowHeight: CGFloat = 46
    static let maxExpandedRows = 5
    static let expandedBottomMargin: CGFloat = 12
    static let screenMargin: CGFloat = 18

    static func expandedSize(sessionCount: Int, screenHeight: CGFloat) -> CGSize {
        let rowCount = max(1, min(sessionCount, maxExpandedRows))
        let desiredHeight = expandedHeaderHeight + CGFloat(rowCount) * rowHeight + expandedBottomMargin
        let maxHeight = max(minExpandedHeight, screenHeight - screenMargin * 2)
        return CGSize(
            width: expandedWidth,
            height: min(max(minExpandedHeight, desiredHeight), maxHeight)
        )
    }
}

@MainActor
final class TrafficLightView: NSView {
    var summary = SessionSummary(status: .inactive, sessions: []) {
        didSet { needsDisplay = true }
    }
    fileprivate var mode: TrafficLightPanelMode = .collapsed {
        didSet { needsDisplay = true }
    }
    var onSetExpanded: ((Bool) -> Void)?
    var onMove: ((CGPoint) -> Void)?
    var onDragStateChange: ((Bool) -> Void)?
    var onRequestClose: (() -> Void)?
    var onQuit: (() -> Void)?
    var onResetPosition: (() -> Void)?

    private var dragStartInScreen: CGPoint?
    private var mouseDownPoint: CGPoint?
    private var dragAllowedForCurrentPress = false
    private var movedDuringDrag = false

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawBackground()

        switch mode {
        case .collapsed:
            drawCollapsed()
        case .expanded:
            drawExpanded()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        window?.makeFirstResponder(self)
        mouseDownPoint = point
        dragStartInScreen = NSEvent.mouseLocation
        dragAllowedForCurrentPress = TrafficLightPanelInteraction.canStartDrag(
            mode: mode,
            point: point,
            bounds: bounds
        )
        movedDuringDrag = false
        if dragAllowedForCurrentPress {
            onDragStateChange?(true)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragAllowedForCurrentPress,
              let previous = dragStartInScreen else {
            return
        }
        let current = NSEvent.mouseLocation
        let delta = CGPoint(x: current.x - previous.x, y: current.y - previous.y)
        if abs(delta.x) > 2 || abs(delta.y) > 2 {
            movedDuringDrag = true
            onMove?(delta)
            dragStartInScreen = current
        }
    }

    override func mouseUp(with event: NSEvent) {
        if dragAllowedForCurrentPress {
            onDragStateChange?(false)
        }
        let point = convert(event.locationInWindow, from: nil)
        let action = TrafficLightPanelInteraction.clickAction(
            mode: mode,
            mouseDown: mouseDownPoint ?? point,
            mouseUp: point,
            bounds: bounds,
            movedDuringDrag: movedDuringDrag
        )
        switch action {
        case .expand:
            onSetExpanded?(true)
        case .collapse:
            onSetExpanded?(false)
        case .requestClose:
            onRequestClose?()
        case .none:
            break
        }
        dragAllowedForCurrentPress = false
        dragStartInScreen = nil
        mouseDownPoint = nil
    }

    override func rightMouseUp(with event: NSEvent) {
        let menu = NSMenu()
        let toggleItem = NSMenuItem(
            title: mode == .expanded ? "Collapse" : "Expand",
            action: #selector(toggleFromMenu),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let resetItem = NSMenuItem(title: "Reset Position", action: #selector(resetPositionFromMenu), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit \(TrafficLightProduct.displayName)", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, mode == .expanded {
            onSetExpanded?(false)
            return
        }
        super.keyDown(with: event)
    }

    @objc private func toggleFromMenu() {
        onSetExpanded?(mode == .collapsed)
    }

    @objc private func resetPositionFromMenu() {
        onResetPosition?()
    }

    @objc private func quitFromMenu() {
        onQuit?()
    }

    private func drawBackground() {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
        NSColor(calibratedWhite: 0.095, alpha: 0.91).setFill()
        path.fill()

        let border = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 26, yRadius: 26)
        border.lineWidth = 2
        ringColor(for: summary.status).withAlphaComponent(summary.status == .inactive ? 0.38 : 0.95).setStroke()
        border.stroke()
    }

    private func drawCollapsed() {
        let statuses: [SessionStatus] = [.working, .waiting, .completed]
        let counts = Dictionary(grouping: summary.sessions, by: \.status).mapValues(\.count)
        var x: CGFloat = 16
        for status in statuses {
            drawMiniStatus(status: status, count: counts[status, default: 0], origin: CGPoint(x: x, y: bounds.midY))
            x += 28
        }

        drawText(
            compactMetricText(label: "Week", percent: totalPercentText(), tokens: totalTokensText(includeUnit: false)),
            in: NSRect(x: bounds.maxX - 118, y: bounds.midY + 2, width: 104, height: 13),
            font: .monospacedDigitSystemFont(ofSize: 9, weight: .semibold),
            color: .white.withAlphaComponent(0.82),
            alignment: .right
        )
        drawText(
            compactMetricText(label: "Today", percent: todayPercentText(), tokens: todayTokensText(includeUnit: false)),
            in: NSRect(x: bounds.maxX - 118, y: bounds.midY - 13, width: 104, height: 13),
            font: .monospacedDigitSystemFont(ofSize: 9, weight: .medium),
            color: .white.withAlphaComponent(0.60),
            alignment: .right
        )
    }

    private func drawExpanded() {
        drawText(
            "AI Sessions",
            in: NSRect(x: 16, y: bounds.height - 42, width: 160, height: 22),
            font: .systemFont(ofSize: 16, weight: .semibold),
            color: .white.withAlphaComponent(0.94),
            alignment: .left
        )
        drawWindowButton(
            kind: .collapse,
            in: TrafficLightPanelInteraction.collapseButtonRect(in: bounds)
        )
        drawWindowButton(
            kind: .close,
            in: TrafficLightPanelInteraction.closeButtonRect(in: bounds)
        )

        let chipWidth = (bounds.width - 42) / 2
        drawTokenChip(
            label: "Quota for this week",
            percent: totalPercentText(),
            tokens: totalTokensText(includeUnit: true),
            in: NSRect(x: 16, y: bounds.height - 78, width: chipWidth, height: 34)
        )
        drawTokenChip(
            label: "Today used",
            percent: todayPercentText(),
            tokens: todayTokensText(includeUnit: true),
            in: NSRect(x: 26 + chipWidth, y: bounds.height - 78, width: chipWidth, height: 34)
        )

        if summary.sessions.isEmpty {
            drawText(
                "No active Codex sessions",
                in: NSRect(x: 16, y: bounds.height - 104, width: bounds.width - 32, height: 22),
                font: .systemFont(ofSize: 13, weight: .medium),
                color: .white.withAlphaComponent(0.62),
                alignment: .left
            )
            return
        }

        let visibleSessions = Array(summary.sessions.prefix(visibleRowCapacity()))
        for (index, session) in visibleSessions.enumerated() {
            drawSessionRow(session, index: index)
        }

        let hiddenCount = summary.sessions.count - visibleSessions.count
        if hiddenCount > 0 {
            drawText(
                "+ \(hiddenCount) more recent sessions",
                in: NSRect(x: 16, y: 9, width: bounds.width - 32, height: 16),
                font: .systemFont(ofSize: 11, weight: .medium),
                color: .white.withAlphaComponent(0.52),
                alignment: .left
            )
        }
    }

    private func drawSessionRow(_ session: AIAgentSession, index: Int) {
        let top = bounds.height - Layout.expandedHeaderHeight - CGFloat(index) * Layout.rowHeight
        let rect = NSRect(
            x: 14,
            y: top - Layout.rowHeight + 7,
            width: bounds.width - 28,
            height: Layout.rowHeight - 7
        )
        let rowPath = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        NSColor.white.withAlphaComponent(0.052).setFill()
        rowPath.fill()
        ringColor(for: session.status).withAlphaComponent(0.22).setStroke()
        rowPath.lineWidth = 0.8
        rowPath.stroke()

        let accent = NSBezierPath(roundedRect: NSRect(x: rect.minX, y: rect.minY, width: 3, height: rect.height), xRadius: 1.5, yRadius: 1.5)
        ringColor(for: session.status).withAlphaComponent(0.95).setFill()
        accent.fill()

        drawDot(status: session.status, center: CGPoint(x: rect.minX + 16, y: rect.maxY - 15))
        drawText(
            session.displayName,
            in: NSRect(x: rect.minX + 32, y: rect.maxY - 20, width: rect.width - 148, height: 15),
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: .white.withAlphaComponent(0.9),
            alignment: .left
        )

        drawStatusPill(session.status, in: NSRect(x: rect.maxX - 86, y: rect.maxY - 21, width: 74, height: 17))

        drawText(
            session.summary,
            in: NSRect(x: rect.minX + 32, y: rect.minY + 7, width: rect.width - 88, height: 14),
            font: .monospacedSystemFont(ofSize: 10, weight: .regular),
            color: .white.withAlphaComponent(session.status == .completed ? 0.50 : 0.70),
            alignment: .left,
            lineBreakMode: .byTruncatingMiddle
        )
        drawText(
            relativeTime(session.lastActivity),
            in: NSRect(x: rect.maxX - 46, y: rect.minY + 7, width: 34, height: 14),
            font: .monospacedDigitSystemFont(ofSize: 10, weight: .medium),
            color: .white.withAlphaComponent(0.52),
            alignment: .right
        )
    }

    private func visibleRowCapacity() -> Int {
        let availableHeight = bounds.height - Layout.expandedHeaderHeight - Layout.expandedBottomMargin
        let capacity = max(0, Int(floor(availableHeight / Layout.rowHeight)))
        if summary.sessions.count > capacity {
            return max(0, capacity - 1)
        }
        return capacity
    }

    private enum WindowButtonKind {
        case collapse
        case close
    }

    private func drawWindowButton(kind: WindowButtonKind, in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        NSColor.white.withAlphaComponent(0.065).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.11).setStroke()
        path.lineWidth = 0.8
        path.stroke()

        NSColor.white.withAlphaComponent(0.62).setStroke()
        let inset = rect.insetBy(dx: 7, dy: 7)
        switch kind {
        case .collapse:
            let minus = NSBezierPath()
            minus.move(to: CGPoint(x: inset.minX, y: rect.midY))
            minus.line(to: CGPoint(x: inset.maxX, y: rect.midY))
            minus.lineWidth = 1.5
            minus.stroke()
        case .close:
            let first = NSBezierPath()
            first.move(to: CGPoint(x: inset.minX, y: inset.minY))
            first.line(to: CGPoint(x: inset.maxX, y: inset.maxY))
            first.lineWidth = 1.4
            first.stroke()

            let second = NSBezierPath()
            second.move(to: CGPoint(x: inset.minX, y: inset.maxY))
            second.line(to: CGPoint(x: inset.maxX, y: inset.minY))
            second.lineWidth = 1.4
            second.stroke()
        }
    }

    private func drawLight(status: SessionStatus, active: Bool, center: CGPoint, radius: CGFloat) {
        let color = ringColor(for: status)
        if active {
            drawGlow(color: color, center: center, radius: radius + 20)
        }

        let outer = NSBezierPath(ovalIn: NSRect(
            x: center.x - radius - 4,
            y: center.y - radius - 4,
            width: (radius + 4) * 2,
            height: (radius + 4) * 2
        ))
        NSColor.black.withAlphaComponent(0.42).setFill()
        outer.fill()

        let light = NSBezierPath(ovalIn: NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        (active ? color : color.withAlphaComponent(0.16)).setFill()
        light.fill()

        NSColor.black.withAlphaComponent(active ? 0.08 : 0.34).setStroke()
        light.lineWidth = 2
        light.stroke()

        if active {
            let shine = NSBezierPath(ovalIn: NSRect(
                x: center.x - radius * 0.34,
                y: center.y - radius * 0.10,
                width: radius * 0.68,
                height: radius * 0.38
            ))
            NSColor.white.withAlphaComponent(0.22).setFill()
            shine.fill()
        }
    }

    private func drawDot(status: SessionStatus, center: CGPoint) {
        let dot = NSBezierPath(ovalIn: NSRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
        ringColor(for: status).setFill()
        dot.fill()
    }

    private func drawMiniStatus(status: SessionStatus, count: Int, origin: CGPoint) {
        let isActive = count > 0
        let color = ringColor(for: status)
        if isActive && summary.status == status {
            drawGlow(color: color, center: origin, radius: 15)
        }

        let dotRect = NSRect(x: origin.x - 5, y: origin.y - 5, width: 10, height: 10)
        let dot = NSBezierPath(ovalIn: dotRect)
        color.withAlphaComponent(isActive ? 1.0 : 0.20).setFill()
        dot.fill()

        if count > 0 {
            drawText(
                "\(count)",
                in: NSRect(x: origin.x + 7, y: origin.y - 7, width: 14, height: 14),
                font: .monospacedDigitSystemFont(ofSize: 10, weight: .semibold),
                color: .white.withAlphaComponent(0.58),
                alignment: .left
            )
        }
    }

    private func drawGlow(color: NSColor, center: CGPoint, radius: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }
        context.saveGState()
        let colors = [
            color.withAlphaComponent(0.42).cgColor,
            color.withAlphaComponent(0.0).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 2,
                endCenter: center,
                endRadius: radius,
                options: []
            )
        }
        context.restoreGState()
    }

    private func drawText(
        _ text: String,
        in rect: NSRect,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = lineBreakMode
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        text.draw(in: rect, withAttributes: attributes)
    }

    private func drawStatusChips() {
        let statuses: [SessionStatus] = [.working, .waiting, .completed]
        let counts = Dictionary(grouping: summary.sessions, by: \.status).mapValues(\.count)
        var x = bounds.width - 178
        for status in statuses {
            let rect = NSRect(x: x, y: bounds.height - 55, width: 48, height: 22)
            drawCountChip(status: status, count: counts[status, default: 0], in: rect)
            x += 54
        }
    }

    private func drawCountChip(status: SessionStatus, count: Int, in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        ringColor(for: status).withAlphaComponent(count > 0 ? 0.14 : 0.055).setFill()
        path.fill()
        ringColor(for: status).withAlphaComponent(count > 0 ? 0.42 : 0.16).setStroke()
        path.lineWidth = 0.8
        path.stroke()

        drawDot(status: status, center: CGPoint(x: rect.minX + 11, y: rect.midY))
        drawText(
            "\(count)",
            in: NSRect(x: rect.minX + 21, y: rect.midY - 7, width: rect.width - 26, height: 14),
            font: .monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            color: .white.withAlphaComponent(count > 0 ? 0.82 : 0.36),
            alignment: .right
        )
    }

    private func drawTokenChip(label: String, percent: String, tokens: String, in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.24, alpha: 0.80).setFill()
        path.fill()
        NSColor(calibratedRed: 0.45, green: 0.72, blue: 0.64, alpha: 0.34).setStroke()
        path.lineWidth = 0.8
        path.stroke()

        drawText(
            label.uppercased(),
            in: NSRect(x: rect.minX + 8, y: rect.maxY - 13, width: rect.width - 16, height: 9),
            font: .systemFont(ofSize: 7, weight: .semibold),
            color: .white.withAlphaComponent(0.42),
            alignment: .left
        )
        drawText(
            percent,
            in: NSRect(x: rect.minX + 8, y: rect.minY + 6, width: 44, height: 13),
            font: .monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            color: .white.withAlphaComponent(0.86),
            alignment: .left
        )
        drawText(
            tokens,
            in: NSRect(x: rect.minX + 54, y: rect.minY + 6, width: rect.width - 62, height: 13),
            font: .monospacedDigitSystemFont(ofSize: 10.5, weight: .medium),
            color: .white.withAlphaComponent(0.70),
            alignment: .right
        )
    }

    private func drawStatusPill(_ status: SessionStatus, in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        ringColor(for: status).withAlphaComponent(0.14).setFill()
        path.fill()
        drawText(
            status.label,
            in: NSRect(x: rect.minX + 6, y: rect.midY - 6, width: rect.width - 12, height: 12),
            font: .systemFont(ofSize: 9.5, weight: .semibold),
            color: ringColor(for: status).withAlphaComponent(0.95),
            alignment: .center
        )
    }

    private func compactMetricText(label: String, percent: String, tokens: String) -> String {
        "\(label) \(percent) \(tokens)"
    }

    private func totalPercentText() -> String {
        percentText(summary.tokenUsage.totalUsedPercent)
    }

    private func todayPercentText() -> String {
        percentText(summary.tokenUsage.todayUsedPercent)
    }

    private func totalTokensText(includeUnit: Bool) -> String {
        guard summary.tokenUsage.updatedAt != nil else {
            return "--"
        }
        return formatTokens(summary.tokenUsage.totalTokens, includeUnit: includeUnit)
    }

    private func todayTokensText(includeUnit: Bool) -> String {
        guard summary.tokenUsage.updatedAt != nil else {
            return "--"
        }
        return formatTokens(summary.tokenUsage.todayTokens, includeUnit: includeUnit)
    }

    private func percentText(_ percent: Double?) -> String {
        guard let percent else {
            return "--"
        }
        if percent >= 100 {
            return "\(Int(percent.rounded()))%"
        }
        if percent >= 10 {
            return "\(Int(percent.rounded()))%"
        }
        return String(format: "%.1f%%", percent)
    }

    private func formatTokens(_ tokens: Int, includeUnit: Bool) -> String {
        let suffix = includeUnit ? " tok" : ""
        if tokens >= 1_000_000 {
            let millions = Double(tokens) / 1_000_000
            let value = millions >= 10 ? String(format: "%.0fM", millions) : String(format: "%.1fM", millions)
            return value + suffix
        }
        if tokens >= 1_000 {
            let thousands = Double(tokens) / 1_000
            let value = thousands >= 10 ? String(format: "%.0fK", thousands) : String(format: "%.1fK", thousands)
            return value + suffix
        }
        return "\(tokens)" + suffix
    }

    private func ringColor(for status: SessionStatus) -> NSColor {
        switch status {
        case .working:
            return NSColor(calibratedRed: 0.95, green: 0.20, blue: 0.18, alpha: 1)
        case .waiting:
            return NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.14, alpha: 1)
        case .completed:
            return NSColor(calibratedRed: 0.36, green: 0.88, blue: 0.35, alpha: 1)
        case .inactive:
            return NSColor(calibratedWhite: 0.55, alpha: 1)
        }
    }

    private func titleText() -> String {
        switch summary.status {
        case .waiting:
            return "Needs your input"
        case .working:
            return "Codex is working"
        case .completed:
            return "Ready"
        case .inactive:
            return TrafficLightProduct.displayName
        }
    }

    private func subtitleText() -> String {
        if summary.sessions.isEmpty {
            return "Watching ~/.codex/sessions"
        }
        return "\(summary.sessions.count) recent session\(summary.sessions.count == 1 ? "" : "s")"
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = max(0, Date().timeIntervalSince(date))
        if seconds < 60 {
            return "\(Int(seconds))s"
        }
        if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        }
        return "\(Int(seconds / 3600))h"
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
