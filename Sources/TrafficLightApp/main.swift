import AppKit
import ApplicationServices
import Darwin
import TrafficLightCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel!
    private var trafficView: TrafficLightView!
    private var timer: Timer?
    private let store = CodexSessionStore()
    private let workspaceFocuser = AgentWorkspaceWindowFocuser()
    private var isExpanded = false
    private var userMovedWindow = false
    private var userResizedWindow = false
    private var expandedUserSize: CGSize?
    private var isDragging = false
    private var refreshInFlight = false
    private var refreshPending = false
    private var tokenRefreshInFlight = false
    private var lastTokenRefresh = Date(timeIntervalSince1970: 0)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        expandedUserSize = loadExpandedUserSize()

        trafficView = TrafficLightView(frame: NSRect(origin: .zero, size: Layout.collapsedSize))
        trafficView.onSetExpanded = { [weak self] expanded in
            self?.setExpanded(expanded)
        }
        trafficView.onMove = { [weak self] delta in
            self?.movePanel(by: delta)
        }
        trafficView.onResize = { [weak self] delta, region in
            self?.resizePanel(by: delta, region: region)
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
        trafficView.onOpenSession = { [weak self] session in
            self?.focusWorkspace(for: session)
        }
        trafficView.onStopSession = { [weak self] session in
            self?.confirmStopSession(session)
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
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let sessions = store.loadSessions(now: now)
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.refreshInFlight = false
                guard !self.isDragging else {
                    return
                }
                self.refreshTokenUsageIfNeeded(now: now)
                self.trafficView.summary = SessionAggregator.aggregate(
                    sessions,
                    tokenUsage: self.trafficView.summary.tokenUsage
                )
                if self.isExpanded {
                    self.resizeExpandedPanel()
                }
                if self.refreshPending {
                    self.refresh()
                }
            }
        }
    }

    private func refreshTokenUsageIfNeeded(now: Date) {
        let shouldRefresh = now.timeIntervalSince(lastTokenRefresh) >= TrafficLightRefreshPolicy.tokenUsageInterval
            || trafficView.summary.tokenUsage.updatedAt == nil
        guard shouldRefresh, !tokenRefreshInFlight else {
            return
        }

        tokenRefreshInFlight = true
        let store = self.store
        DispatchQueue.global(qos: .background).async { [weak self] in
            let tokenUsage = store.loadTokenUsage(now: now)
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.tokenRefreshInFlight = false
                self.lastTokenRefresh = now
                self.trafficView.summary = SessionAggregator.aggregate(
                    self.trafficView.summary.sessions,
                    tokenUsage: tokenUsage
                )
                if self.isExpanded {
                    self.resizeExpandedPanel()
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

    private func focusWorkspace(for session: AIAgentSession) {
        switch workspaceFocuser.focus(session: session) {
        case .focused:
            break
        case .activatedOwningApp:
            break
        case .needsAccessibilityPermission:
            showAccessibilityPermissionAlert()
        case .noMatchingWindow:
            showNoMatchingWindowAlert(session: session)
        }
    }

    private func confirmStopSession(_ session: AIAgentSession) {
        guard let pid = session.codexProcessID else {
            return
        }

        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Stop Codex session?"
        alert.informativeText = "This will terminate PID \(pid) for \(session.displayName)."
        alert.addButton(withTitle: "Stop")
        alert.addButton(withTitle: "Cancel")
        alert.window.level = .floating
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        if stopCodexProcess(pid: pid) {
            refresh()
        } else {
            showStopFailedAlert(session: session, pid: pid)
        }
    }

    private func stopCodexProcess(pid: Int) -> Bool {
        let result = Darwin.kill(pid_t(pid), SIGTERM)
        return result == 0 || errno == ESRCH
    }

    private func showStopFailedAlert(session: AIAgentSession, pid: Int) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not stop Codex"
        alert.informativeText = "Mushi Signal could not terminate PID \(pid) for \(session.displayName)."
        alert.addButton(withTitle: "OK")
        alert.window.level = .floating
        alert.runModal()
    }

    private func showAccessibilityPermissionAlert() {
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Enable window switching?"
        alert.informativeText = "\(TrafficLightProduct.displayName) needs Accessibility access to jump to the Codex terminal or IDE window for a task."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        alert.window.level = .floating
        if alert.runModal() == .alertFirstButtonReturn {
            workspaceFocuser.requestAccessibilityPermissionPrompt()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func showNoMatchingWindowAlert(session: AIAgentSession) {
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "No matching window found"
        alert.informativeText = "I could not find a Codex terminal or IDE window for \(session.displayName). Open the project window and try again."
        alert.addButton(withTitle: "OK")
        alert.window.level = .floating
        alert.runModal()
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
        if let expandedUserSize {
            return expandedUserSize
        }
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

    private func resizePanel(by delta: CGPoint, region: TrafficLightPanelHitRegion) {
        guard isExpanded else {
            return
        }

        userResizedWindow = true
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = panel.frame
        let minSize = Layout.minimumExpandedSize
        let requestedWidth: CGFloat
        if region.resizesLeft {
            requestedWidth = frame.width - delta.x
        } else if region.resizesRight {
            requestedWidth = frame.width + delta.x
        } else {
            requestedWidth = frame.width
        }

        let requestedHeight: CGFloat
        if region.resizesTop {
            requestedHeight = frame.height + delta.y
        } else if region.resizesBottom {
            requestedHeight = frame.height - delta.y
        } else {
            requestedHeight = frame.height
        }

        let maxWidth: CGFloat
        if region.resizesLeft {
            maxWidth = max(minSize.width, frame.maxX - screen.minX - Layout.screenMargin)
        } else if region.resizesRight {
            maxWidth = max(minSize.width, screen.maxX - frame.minX - Layout.screenMargin)
        } else {
            maxWidth = frame.width
        }

        let maxHeight: CGFloat
        if region.resizesBottom {
            maxHeight = max(minSize.height, frame.maxY - screen.minY - Layout.screenMargin)
        } else if region.resizesTop {
            maxHeight = max(minSize.height, screen.maxY - frame.minY - Layout.screenMargin)
        } else {
            maxHeight = frame.height
        }

        let maxSize = CGSize(
            width: maxWidth,
            height: maxHeight
        )
        let nextSize = TrafficLightPanelResize.clampedSize(
            CGSize(width: requestedWidth, height: requestedHeight),
            minSize: minSize,
            maxSize: maxSize
        )
        let nextFrame = NSRect(
            x: region.resizesLeft ? frame.maxX - nextSize.width : frame.minX,
            y: region.resizesBottom ? frame.maxY - nextSize.height : frame.minY,
            width: nextSize.width,
            height: nextSize.height
        )
        expandedUserSize = nextSize
        saveExpandedUserSize(nextSize)
        trafficView.setFrameSize(nextSize)
        panel.setFrame(nextFrame, display: true)
    }

    private func loadExpandedUserSize() -> CGSize? {
        let defaults = UserDefaults.standard
        let width = defaults.double(forKey: DefaultsKey.expandedWidth)
        let height = defaults.double(forKey: DefaultsKey.expandedHeight)
        guard width > 0, height > 0 else {
            return nil
        }

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return TrafficLightPanelResize.clampedSize(
            CGSize(width: width, height: height),
            minSize: Layout.minimumExpandedSize,
            maxSize: CGSize(
                width: max(Layout.minimumExpandedSize.width, screen.width - Layout.screenMargin * 2),
                height: max(Layout.minimumExpandedSize.height, screen.height - Layout.screenMargin * 2)
            )
        )
    }

    private func saveExpandedUserSize(_ size: CGSize) {
        let defaults = UserDefaults.standard
        defaults.set(size.width, forKey: DefaultsKey.expandedWidth)
        defaults.set(size.height, forKey: DefaultsKey.expandedHeight)
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

private enum DefaultsKey {
    static let expandedWidth = "expandedWidth"
    static let expandedHeight = "expandedHeight"
}

private enum Layout {
    static let collapsedSize = CGSize(width: 214, height: 44)
    static let expandedWidth: CGFloat = 390
    static let expandedHeaderHeight: CGFloat = 94
    static let rowHeight: CGFloat = 46
    static let expandedBottomMargin: CGFloat = 12
    static let screenMargin: CGFloat = 18
    static let minExpandedHeight: CGFloat = expandedHeaderHeight + CGFloat(TrafficLightExpandedListLayout.defaultVisibleRows) * rowHeight + expandedBottomMargin
    static let minimumExpandedSize = CGSize(width: 380, height: minExpandedHeight)

    static func expandedSize(sessionCount: Int, screenHeight: CGFloat) -> CGSize {
        let rowCount = TrafficLightExpandedListLayout.defaultVisibleRows
        let desiredHeight = expandedHeaderHeight + CGFloat(rowCount) * rowHeight + expandedBottomMargin
        let maxHeight = max(minExpandedHeight, screenHeight - screenMargin * 2)
        return CGSize(
            width: expandedWidth,
            height: min(max(minExpandedHeight, desiredHeight), maxHeight)
        )
    }
}

private enum AgentWorkspaceFocusResult {
    case focused(AgentWorkspaceWindowMatch)
    case activatedOwningApp
    case needsAccessibilityPermission
    case noMatchingWindow
}

private final class AgentWorkspaceWindowFocuser {
    private struct WindowCandidate {
        let snapshot: AgentWorkspaceWindowSnapshot
        let app: NSRunningApplication
        let element: AXUIElement
    }

    func focus(session: AIAgentSession) -> AgentWorkspaceFocusResult {
        guard AXIsProcessTrusted() else {
            return .needsAccessibilityPermission
        }

        if let focused = focusVisibleWindow(session: session) {
            return focused
        }

        if activateOwningApp(for: session) {
            Thread.sleep(forTimeInterval: 0.18)
            if let focused = focusVisibleWindow(session: session) {
                return focused
            }
            return .activatedOwningApp
        }

        return .noMatchingWindow
    }

    private func focusVisibleWindow(session: AIAgentSession) -> AgentWorkspaceFocusResult? {
        let candidates = windowCandidates()
        guard let match = AgentWorkspaceWindowMatcher.bestMatch(
            for: session,
            windows: candidates.map(\.snapshot)
        ),
        let candidate = candidates.first(where: { $0.snapshot == match.window }) else {
            return nil
        }

        candidate.app.activate(options: [.activateIgnoringOtherApps])
        AXUIElementSetAttributeValue(candidate.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(candidate.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        return .focused(match)
    }

    private func activateOwningApp(for session: AIAgentSession) -> Bool {
        guard let codexProcessID = session.codexProcessID,
              let psOutput = runProcess(executable: "/bin/ps", arguments: ["-axo", "pid,ppid,command"]) else {
            return false
        }

        let appPIDs = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular || $0.activationPolicy == .accessory }
            .map { Int($0.processIdentifier) }
        guard let ownerPID = RunningCodexProcesses.nearestAncestorPID(
            from: codexProcessID,
            candidatePIDs: appPIDs,
            psOutput: psOutput
        ),
        let app = NSRunningApplication(processIdentifier: pid_t(ownerPID)) else {
            return false
        }

        return app.activate(options: [.activateIgnoringOtherApps])
    }

    private func runProcess(executable: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let output = String(data: data, encoding: .utf8) else {
                return nil
            }
            return output
        } catch {
            return nil
        }
    }

    func requestAccessibilityPermissionPrompt() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    func windowSnapshotsForDiagnostics() -> [AgentWorkspaceWindowSnapshot]? {
        guard AXIsProcessTrusted() else {
            return nil
        }
        return windowCandidates().map(\.snapshot)
    }

    private func windowCandidates() -> [WindowCandidate] {
        NSWorkspace.shared.runningApplications.flatMap { app -> [WindowCandidate] in
            guard let appName = app.localizedName,
                  app.activationPolicy == .regular || app.activationPolicy == .accessory else {
                return []
            }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            guard let windows: [AXUIElement] = copyAttribute(kAXWindowsAttribute, from: appElement) else {
                return []
            }

            return windows.compactMap { window in
                let title: String = copyAttribute(kAXTitleAttribute, from: window) ?? ""
                guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return WindowCandidate(
                    snapshot: AgentWorkspaceWindowSnapshot(appName: appName, title: title),
                    app: app,
                    element: window
                )
            }
        }
    }

    private func copyAttribute<T>(_ attribute: String, from element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? T
    }
}

@MainActor
final class TrafficLightView: NSView {
    var summary = SessionSummary(status: .inactive, sessions: []) {
        didSet {
            preserveScrollAnchor(oldSessions: oldValue.sessions, newSessions: summary.sessions)
            clampScrollOffset()
            needsDisplay = true
        }
    }
    fileprivate var mode: TrafficLightPanelMode = .collapsed {
        didSet {
            discardCursorRects()
            needsDisplay = true
        }
    }
    var onSetExpanded: ((Bool) -> Void)?
    var onMove: ((CGPoint) -> Void)?
    var onResize: ((CGPoint, TrafficLightPanelHitRegion) -> Void)?
    var onDragStateChange: ((Bool) -> Void)?
    var onRequestClose: (() -> Void)?
    var onQuit: (() -> Void)?
    var onResetPosition: (() -> Void)?
    var onOpenSession: ((AIAgentSession) -> Void)?
    var onStopSession: ((AIAgentSession) -> Void)?

    private var dragStartInScreen: CGPoint?
    private var mouseDownPoint: CGPoint?
    private var dragAllowedForCurrentPress = false
    private var resizeRegionForCurrentPress: TrafficLightPanelHitRegion?
    private var movedDuringDrag = false
    private var scrollOffset: CGFloat = 0
    private var cachedMushiBugImage: NSImage?
    private var cachedMushiStatusImages: [String: NSImage] = [:]

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
        let hitRegion = TrafficLightPanelInteraction.hitRegion(
            mode: mode,
            point: point,
            bounds: bounds
        )
        resizeRegionForCurrentPress = hitRegion.isResizeRegion ? hitRegion : nil
        movedDuringDrag = false
        if dragAllowedForCurrentPress {
            onDragStateChange?(true)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let previous = dragStartInScreen else {
            return
        }
        let current = NSEvent.mouseLocation
        let delta = CGPoint(x: current.x - previous.x, y: current.y - previous.y)
        if abs(delta.x) > 2 || abs(delta.y) > 2 {
            movedDuringDrag = true
        }
        if let resizeRegion = resizeRegionForCurrentPress {
            onResize?(delta, resizeRegion)
            dragStartInScreen = current
            return
        }
        guard dragAllowedForCurrentPress else {
            return
        }
        if movedDuringDrag {
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
            if let clicked = clickedSessionAction(mouseUp: point) {
                switch clicked.action {
                case .open:
                    onOpenSession?(clicked.session)
                case .stop:
                    onStopSession?(clicked.session)
                }
            }
        }
        dragAllowedForCurrentPress = false
        resizeRegionForCurrentPress = nil
        dragStartInScreen = nil
        mouseDownPoint = nil
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard mode == .expanded else {
            return
        }
        let edge = TrafficLightPanelInteraction.expandedResizeEdgeThickness
        let corner = TrafficLightPanelInteraction.expandedResizeHandleSize
        addCursorRect(
            NSRect(x: 0, y: 0, width: edge, height: bounds.height),
            cursor: .resizeLeftRight
        )
        addCursorRect(
            NSRect(x: bounds.maxX - edge, y: 0, width: edge, height: bounds.height),
            cursor: .resizeLeftRight
        )
        addCursorRect(
            NSRect(x: 0, y: bounds.maxY - edge, width: bounds.width, height: edge),
            cursor: .resizeUpDown
        )
        addCursorRect(
            NSRect(x: 0, y: 0, width: bounds.width, height: edge),
            cursor: .resizeUpDown
        )
        addCursorRect(
            NSRect(x: 0, y: bounds.maxY - corner, width: corner, height: corner),
            cursor: diagonalResizeCursor(rising: false)
        )
        addCursorRect(
            NSRect(x: bounds.maxX - corner, y: 0, width: corner, height: corner),
            cursor: diagonalResizeCursor(rising: false)
        )
        addCursorRect(
            NSRect(x: bounds.maxX - corner, y: bounds.maxY - corner, width: corner, height: corner),
            cursor: diagonalResizeCursor(rising: true)
        )
        addCursorRect(
            NSRect(x: 0, y: 0, width: corner, height: corner),
            cursor: diagonalResizeCursor(rising: true)
        )
    }

    private func diagonalResizeCursor(rising: Bool) -> NSCursor {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        NSColor.black.withAlphaComponent(0.80).setStroke()
        let path = NSBezierPath()
        if rising {
            path.move(to: NSPoint(x: 4, y: 14))
            path.line(to: NSPoint(x: 14, y: 4))
        } else {
            path.move(to: NSPoint(x: 4, y: 4))
            path.line(to: NSPoint(x: 14, y: 14))
        }
        path.lineWidth = 2
        path.lineCapStyle = .round
        path.stroke()
        image.unlockFocus()
        return NSCursor(image: image, hotSpot: NSPoint(x: 9, y: 9))
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

    override func scrollWheel(with event: NSEvent) {
        guard mode == .expanded,
              summary.sessions.count > visibleRowCapacity() else {
            super.scrollWheel(with: event)
            return
        }

        scrollOffset -= event.scrollingDeltaY
        clampScrollOffset()
        needsDisplay = true
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
        let counts = Dictionary(grouping: summary.sessions, by: \.status).mapValues(\.count)
        for (index, status) in TrafficLightCollapsedStatusLayout.statuses.enumerated() {
            drawCompactMushiStatus(
                status: status,
                count: counts[status, default: 0],
                index: index
            )
        }

        drawText(
            TrafficLightTokenDisplay.compactWeekly(summary.tokenUsage),
            in: NSRect(x: bounds.maxX - 118, y: bounds.midY + 2, width: 104, height: 13),
            font: .monospacedDigitSystemFont(ofSize: 9, weight: .semibold),
            color: .white.withAlphaComponent(0.82),
            alignment: .right
        )
        drawText(
            TrafficLightTokenDisplay.compactToday(summary.tokenUsage),
            in: NSRect(x: bounds.maxX - 118, y: bounds.midY - 13, width: 104, height: 13),
            font: .monospacedDigitSystemFont(ofSize: 9, weight: .medium),
            color: .white.withAlphaComponent(0.60),
            alignment: .right
        )
    }

    private func drawExpanded() {
        drawExpandedHeader()
        drawWindowButton(
            kind: .collapse,
            in: TrafficLightPanelInteraction.collapseButtonRect(in: bounds)
        )
        drawWindowButton(
            kind: .close,
            in: TrafficLightPanelInteraction.closeButtonRect(in: bounds)
        )

        let chipWidth = (bounds.width - 42) / 2
        let weeklyMetric = TrafficLightTokenDisplay.weekly(summary.tokenUsage)
        let todayMetric = TrafficLightTokenDisplay.today(summary.tokenUsage)
        drawTokenChip(
            label: weeklyMetric.label,
            primary: weeklyMetric.primary,
            secondary: weeklyMetric.secondary,
            in: NSRect(x: 16, y: bounds.height - 78, width: chipWidth, height: 34)
        )
        drawTokenChip(
            label: todayMetric.label,
            primary: todayMetric.primary,
            secondary: todayMetric.secondary,
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

        let visibleRows = visibleRowCapacity()
        let listRect = listViewportRect()
        let visibleRange = TrafficLightExpandedListLayout.visibleRange(
            sessionCount: summary.sessions.count,
            visibleRows: visibleRows,
            scrollOffset: scrollOffset,
            rowHeight: Layout.rowHeight
        )
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: listRect).addClip()
        for index in visibleRange {
            drawSessionRow(summary.sessions[index], absoluteIndex: index)
        }
        NSGraphicsContext.restoreGraphicsState()

        if summary.sessions.count > visibleRows {
            drawScrollIndicator(
                totalRows: summary.sessions.count,
                visibleRows: visibleRows,
                offset: scrollOffset
            )
        }
        drawResizeGrip()
    }

    private func drawExpandedHeader() {
        let iconHeight = TrafficLightExpandedHeader.iconHeight
        let iconWidth = iconHeight
        let iconGap: CGFloat = 5
        let controlGap: CGFloat = 8
        let countWidth: CGFloat = 26
        let titleY = bounds.height - 42
        let titleHeight = TrafficLightExpandedHeader.titleLineHeight
        let collapseRect = TrafficLightPanelInteraction.collapseButtonRect(in: bounds)
        let iconRect = NSRect(
            x: collapseRect.minX - controlGap - iconWidth,
            y: titleY,
            width: iconWidth,
            height: iconHeight
        )
        let countRect = NSRect(
            x: iconRect.minX - iconGap - countWidth,
            y: titleY,
            width: countWidth,
            height: titleHeight
        )
        drawText(
            TrafficLightExpandedHeader.title,
            in: NSRect(x: 16, y: titleY, width: max(80, countRect.minX - 24), height: titleHeight),
            font: .systemFont(ofSize: TrafficLightExpandedHeader.titleFontSize, weight: .semibold),
            color: .white.withAlphaComponent(0.94),
            alignment: .left
        )
        drawText(
            TrafficLightExpandedHeader.countText(sessionCount: summary.sessions.count),
            in: countRect,
            font: .monospacedDigitSystemFont(ofSize: TrafficLightExpandedHeader.countFontSize, weight: .semibold),
            color: .white.withAlphaComponent(0.88),
            alignment: .right
        )
        drawMushiIcon(in: iconRect)
    }

    private func drawSessionRow(_ session: AIAgentSession, absoluteIndex: Int) {
        let rect = sessionRowRect(absoluteIndex: absoluteIndex)
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
        let contentWidth = TrafficLightSessionRowLayout.contentTextWidth(in: rect)
        drawText(
            session.displayName,
            in: NSRect(x: rect.minX + 32, y: rect.maxY - 20, width: contentWidth, height: 15),
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: .white.withAlphaComponent(0.9),
            alignment: .left
        )

        drawStatusPill(session.status, in: TrafficLightSessionRowLayout.statusPillRect(in: rect))

        drawText(
            session.summary,
            in: NSRect(x: rect.minX + 32, y: rect.minY + 7, width: contentWidth, height: 14),
            font: .monospacedSystemFont(ofSize: 10, weight: .regular),
            color: .white.withAlphaComponent(session.status == .completed ? 0.50 : 0.70),
            alignment: .left,
            lineBreakMode: .byTruncatingMiddle
        )
        drawText(
            relativeTime(session.lastActivity),
            in: TrafficLightSessionRowLayout.relativeTimeRect(in: rect),
            font: .monospacedDigitSystemFont(ofSize: 9.5, weight: .medium),
            color: .white.withAlphaComponent(0.52),
            alignment: .right
        )
        drawSessionActionButton(
            kind: .open,
            in: TrafficLightSessionRowLayout.openButtonVisualRect(in: rect),
            enabled: true
        )
        drawSessionActionButton(
            kind: .stop,
            in: TrafficLightSessionRowLayout.stopButtonVisualRect(in: rect),
            enabled: session.codexProcessID != nil
        )
    }

    private func visibleRowCapacity() -> Int {
        let availableHeight = bounds.height - Layout.expandedHeaderHeight - Layout.expandedBottomMargin
        return max(1, Int(floor(availableHeight / Layout.rowHeight)))
    }

    private func listViewportRect() -> NSRect {
        NSRect(
            x: 0,
            y: Layout.expandedBottomMargin,
            width: bounds.width,
            height: max(0, bounds.height - Layout.expandedHeaderHeight - Layout.expandedBottomMargin)
        )
    }

    private struct ClickedSessionAction {
        let session: AIAgentSession
        let action: TrafficLightSessionRowAction
    }

    private func clickedSessionAction(mouseUp point: CGPoint) -> ClickedSessionAction? {
        guard mode == .expanded,
              !movedDuringDrag,
              let mouseDownPoint,
              let downHit = sessionHit(at: mouseDownPoint),
              let upHit = sessionHit(at: point),
              downHit.session.id == upHit.session.id,
              let downAction = TrafficLightSessionRowLayout.action(
                at: mouseDownPoint,
                in: downHit.row,
                canStop: downHit.session.codexProcessID != nil
              ),
              let upAction = TrafficLightSessionRowLayout.action(
                at: point,
                in: upHit.row,
                canStop: upHit.session.codexProcessID != nil
              ),
              downAction == upAction else {
            return nil
        }
        return ClickedSessionAction(session: upHit.session, action: upAction)
    }

    private func sessionHit(at point: CGPoint) -> (session: AIAgentSession, row: NSRect)? {
        guard !summary.sessions.isEmpty else {
            return nil
        }

        let visibleRows = visibleRowCapacity()
        let visibleRange = TrafficLightExpandedListLayout.visibleRange(
            sessionCount: summary.sessions.count,
            visibleRows: visibleRows,
            scrollOffset: scrollOffset,
            rowHeight: Layout.rowHeight
        )
        for absoluteIndex in visibleRange {
            let row = sessionRowRect(absoluteIndex: absoluteIndex)
            guard row.contains(point) else {
                continue
            }
            return (summary.sessions[absoluteIndex], row)
        }
        return nil
    }

    private func sessionRowRect(absoluteIndex: Int) -> NSRect {
        let top = bounds.height - Layout.expandedHeaderHeight - CGFloat(absoluteIndex) * Layout.rowHeight + scrollOffset
        return NSRect(
            x: 14,
            y: top - Layout.rowHeight + 7,
            width: bounds.width - 28,
            height: Layout.rowHeight - 7
        )
    }

    private func clampScrollOffset() {
        scrollOffset = TrafficLightExpandedListLayout.clampedScrollOffset(
            scrollOffset,
            sessionCount: summary.sessions.count,
            visibleRows: visibleRowCapacity(),
            rowHeight: Layout.rowHeight
        )
    }

    private func preserveScrollAnchor(oldSessions: [AIAgentSession], newSessions: [AIAgentSession]) {
        guard mode == .expanded,
              oldSessions.map(\.id) != newSessions.map(\.id) else {
            return
        }
        scrollOffset = TrafficLightExpandedListLayout.scrollOffsetPreservingAnchor(
            oldIDs: oldSessions.map(\.id),
            newIDs: newSessions.map(\.id),
            currentOffset: scrollOffset,
            visibleRows: visibleRowCapacity(),
            rowHeight: Layout.rowHeight
        )
    }

    private func drawScrollIndicator(totalRows: Int, visibleRows: Int, offset: CGFloat) {
        guard totalRows > visibleRows, visibleRows > 0 else {
            return
        }

        let listRect = listViewportRect()
        let track = NSRect(
            x: bounds.maxX - 8,
            y: listRect.minY + 8,
            width: 3,
            height: listRect.height - 16
        )
        let trackPath = NSBezierPath(roundedRect: track, xRadius: 1.5, yRadius: 1.5)
        NSColor.white.withAlphaComponent(0.08).setFill()
        trackPath.fill()

        let fraction = CGFloat(visibleRows) / CGFloat(totalRows)
        let thumbHeight = max(20, track.height * fraction)
        let maxOffset = max(1, TrafficLightExpandedListLayout.maxScrollOffset(
            sessionCount: totalRows,
            visibleRows: visibleRows,
            rowHeight: Layout.rowHeight
        ))
        let travel = max(0, track.height - thumbHeight)
        let normalizedOffset = TrafficLightExpandedListLayout.clampedScrollOffset(
            offset,
            sessionCount: totalRows,
            visibleRows: visibleRows,
            rowHeight: Layout.rowHeight
        ) / maxOffset
        let thumbY = track.maxY - thumbHeight - travel * normalizedOffset
        let thumb = NSRect(x: track.minX, y: thumbY, width: track.width, height: thumbHeight)
        let thumbPath = NSBezierPath(roundedRect: thumb, xRadius: 1.5, yRadius: 1.5)
        NSColor.white.withAlphaComponent(0.34).setFill()
        thumbPath.fill()
    }

    private func drawResizeGrip() {
        let handle = TrafficLightPanelInteraction.resizeHandleRect(in: bounds)
        NSColor.white.withAlphaComponent(0.18).setStroke()
        for index in 0..<3 {
            let inset = CGFloat(index) * 5 + 6
            let path = NSBezierPath()
            path.move(to: CGPoint(x: handle.maxX - inset, y: handle.minY + 5))
            path.line(to: CGPoint(x: handle.maxX - 5, y: handle.minY + inset))
            path.lineWidth = 0.9
            path.stroke()
        }
    }

    private enum WindowButtonKind {
        case collapse
        case close
    }

    private enum SessionActionButtonKind {
        case open
        case stop
    }

    private func drawSessionActionButton(kind: SessionActionButtonKind, in rect: NSRect, enabled: Bool) {
        let color: NSColor
        let title: String
        switch kind {
        case .open:
            color = NSColor(calibratedRed: 0.74, green: 0.90, blue: 1.00, alpha: 1)
            title = "Open"
        case .stop:
            color = NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.34, alpha: 1)
            title = "Kill"
        }
        drawLightActionText(title, in: rect, color: color, enabled: enabled)
    }

    private func drawLightActionText(_ text: String, in rect: NSRect, color: NSColor, enabled: Bool) {
        let button = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        color.withAlphaComponent(enabled ? 0.15 : 0.04).setFill()
        button.fill()
        color.withAlphaComponent(enabled ? 0.38 : 0.12).setStroke()
        button.lineWidth = 0.7
        button.stroke()
        drawText(
            text,
            in: NSRect(x: rect.minX + 4, y: rect.midY - 6.5, width: rect.width - 8, height: 13),
            font: .systemFont(ofSize: TrafficLightSessionRowLayout.actionFontSize, weight: .semibold),
            color: enabled ? color.blended(withFraction: 0.26, of: .white) ?? color : color.withAlphaComponent(0.30),
            alignment: .center
        )
    }

    private func drawStopActionGlyph(in rect: NSRect, color: NSColor, enabled: Bool) {
        let circle = NSBezierPath(ovalIn: rect)
        color.withAlphaComponent(enabled ? 0.12 : 0.04).setFill()
        circle.fill()
        color.withAlphaComponent(enabled ? 0.45 : 0.14).setStroke()
        circle.lineWidth = 0.8
        circle.stroke()

        color.withAlphaComponent(enabled ? 0.74 : 0.22).setStroke()
        let inset = rect.insetBy(dx: 4.5, dy: 4.5)
        let first = NSBezierPath()
        first.move(to: CGPoint(x: inset.minX, y: inset.minY))
        first.line(to: CGPoint(x: inset.maxX, y: inset.maxY))
        first.lineWidth = 1.0
        first.lineCapStyle = .round
        first.stroke()

        let second = NSBezierPath()
        second.move(to: CGPoint(x: inset.minX, y: inset.maxY))
        second.line(to: CGPoint(x: inset.maxX, y: inset.minY))
        second.lineWidth = 1.0
        second.lineCapStyle = .round
        second.stroke()
    }

    private func drawOpenGlyph(in rect: NSRect) {
        let lens = NSRect(x: rect.midX - 5, y: rect.midY - 3, width: 8, height: 8)
        let circle = NSBezierPath(ovalIn: lens)
        circle.lineWidth = 1.2
        circle.stroke()

        let handle = NSBezierPath()
        handle.move(to: CGPoint(x: lens.maxX - 1, y: lens.minY + 1))
        handle.line(to: CGPoint(x: lens.maxX + 4, y: lens.minY - 4))
        handle.lineWidth = 1.2
        handle.lineCapStyle = .round
        handle.stroke()
    }

    private func drawStopGlyph(in rect: NSRect) {
        let side: CGFloat = 8
        let stop = NSBezierPath(roundedRect: NSRect(
            x: rect.midX - side / 2,
            y: rect.midY - side / 2,
            width: side,
            height: side
        ), xRadius: 1.5, yRadius: 1.5)
        stop.lineWidth = 1.2
        stop.stroke()
    }

    private func drawWindowButton(kind: WindowButtonKind, in rect: NSRect) {
        let diameter = TrafficLightWindowControlStyle.visualDiameter
        let visualRect = NSRect(
            x: rect.midX - diameter / 2,
            y: rect.midY - diameter / 2,
            width: diameter,
            height: diameter
        )
        let dot = NSBezierPath(ovalIn: visualRect)
        controlColor(for: kind).withAlphaComponent(0.90).setFill()
        dot.fill()
        NSColor.white.withAlphaComponent(0.18).setStroke()
        dot.lineWidth = 0.6
        dot.stroke()

        NSColor.black.withAlphaComponent(0.42).setStroke()
        let inset = visualRect.insetBy(dx: 3.5, dy: 3.5)
        switch kind {
        case .collapse:
            let minus = NSBezierPath()
            minus.move(to: CGPoint(x: inset.minX, y: rect.midY))
            minus.line(to: CGPoint(x: inset.maxX, y: rect.midY))
            minus.lineWidth = 1.1
            minus.stroke()
        case .close:
            let first = NSBezierPath()
            first.move(to: CGPoint(x: inset.minX, y: inset.minY))
            first.line(to: CGPoint(x: inset.maxX, y: inset.maxY))
            first.lineWidth = 1.0
            first.stroke()

            let second = NSBezierPath()
            second.move(to: CGPoint(x: inset.minX, y: inset.maxY))
            second.line(to: CGPoint(x: inset.maxX, y: inset.minY))
            second.lineWidth = 1.0
            second.stroke()
        }
    }

    private func drawMushiIcon(in rect: NSRect) {
        let image = mushiStatusImage(named: TrafficLightExpandedHeader.iconAssetName) ?? mushiBugImage()
        image?.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private func mushiIconImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "MushiSignal", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSApp.applicationIconImage
    }

    private func mushiBugImage() -> NSImage? {
        if let cachedMushiBugImage {
            return cachedMushiBugImage
        }
        if let url = Bundle.main.url(forResource: "mushi-bug", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            cachedMushiBugImage = image
            return image
        }
        guard let source = mushiIconImage(),
              let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return source
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        for offset in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = Int(pixels[offset])
            let green = Int(pixels[offset + 1])
            let blue = Int(pixels[offset + 2])
            let maxChannel = max(red, green, blue)
            let tealBackground = blue > 55 && green > 35 && red < 80
            let veryDark = maxChannel < 45
            if tealBackground || veryDark {
                pixels[offset + 3] = 0
            }
        }

        guard let output = context.makeImage() else {
            return source
        }
        let image = NSImage(cgImage: output, size: source.size)
        cachedMushiBugImage = image
        return image
    }

    private func mushiStatusImage(named name: String) -> NSImage? {
        if let cached = cachedMushiStatusImages[name] {
            return cached
        }
        if let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "mushi-status"
        ),
        let image = NSImage(contentsOf: url) {
            cachedMushiStatusImages[name] = image
            return image
        }
        return nil
    }

    private func controlColor(for kind: WindowButtonKind) -> NSColor {
        switch kind {
        case .collapse:
            return NSColor(calibratedRed: 1.00, green: 0.70, blue: 0.18, alpha: 1)
        case .close:
            return NSColor(calibratedRed: 0.96, green: 0.28, blue: 0.23, alpha: 1)
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

    private func drawCompactMushiStatus(status: SessionStatus, count: Int, index: Int) {
        let iconRect = TrafficLightCollapsedStatusLayout.iconRect(index: index, in: bounds)
        let assetName = TrafficLightCollapsedStatusLayout.assetName(for: status, count: count)
        let isActive = count > 0
        let color = ringColor(for: status)
        if isActive && summary.status == status {
            drawGlow(
                color: color,
                center: CGPoint(x: iconRect.midX, y: iconRect.midY),
                radius: 19
            )
        }

        if let image = mushiStatusImage(named: assetName) {
            image.draw(
                in: iconRect,
                from: .zero,
                operation: .sourceOver,
                fraction: isActive ? 1.0 : 0.72,
                respectFlipped: false,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        } else {
            drawMiniStatus(
                status: status,
                count: count,
                origin: CGPoint(x: iconRect.midX, y: iconRect.midY)
            )
        }

        guard count > 0 else {
            return
        }

        let badgeRect = TrafficLightCollapsedStatusLayout.countBadgeRect(for: iconRect)
        let badge = NSBezierPath(ovalIn: badgeRect)
        NSColor(calibratedWhite: 0.08, alpha: 0.88).setFill()
        badge.fill()
        color.withAlphaComponent(0.72).setStroke()
        badge.lineWidth = 0.7
        badge.stroke()
        drawText(
            count > 9 ? "9+" : "\(count)",
            in: badgeRect.insetBy(dx: 1, dy: 1.8),
            font: .monospacedDigitSystemFont(ofSize: count > 9 ? 6.5 : 7.5, weight: .bold),
            color: .white.withAlphaComponent(0.92),
            alignment: .center
        )
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

    private func drawTokenChip(label: String, primary: String, secondary: String?, in rect: NSRect) {
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
            primary,
            in: NSRect(x: rect.minX + 8, y: rect.minY + 6, width: secondary == nil ? rect.width - 16 : 68, height: 13),
            font: .monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            color: .white.withAlphaComponent(0.86),
            alignment: .left
        )
        if let secondary {
            drawText(
                secondary,
                in: NSRect(x: rect.minX + 78, y: rect.minY + 6, width: rect.width - 86, height: 13),
                font: .monospacedDigitSystemFont(ofSize: 10.5, weight: .medium),
                color: .white.withAlphaComponent(0.70),
                alignment: .right
            )
        }
    }

    private func drawStatusPill(_ status: SessionStatus, in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        ringColor(for: status).withAlphaComponent(0.14).setFill()
        path.fill()
        drawText(
            status.label,
            in: NSRect(x: rect.minX + 6, y: rect.midY - 6.5, width: rect.width - 12, height: 13),
            font: .systemFont(ofSize: TrafficLightSessionRowLayout.statusFontSize, weight: .semibold),
            color: ringColor(for: status).withAlphaComponent(0.95),
            alignment: .center
        )
    }

    private func ringColor(for status: SessionStatus) -> NSColor {
        switch status {
        case .working:
            return NSColor(calibratedRed: 0.95, green: 0.20, blue: 0.18, alpha: 1)
        case .waiting:
            return NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.14, alpha: 1)
        case .completed:
            return NSColor(calibratedRed: 0.36, green: 0.88, blue: 0.35, alpha: 1)
        case .ended:
            return NSColor(calibratedWhite: 0.58, alpha: 1)
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
        case .ended:
            return "Recently ended"
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

if CommandLine.arguments.contains("--print-accessibility-trust") {
    let trusted = AXIsProcessTrusted()
    print(trusted ? "trusted" : "not-trusted")
    exit(trusted ? EXIT_SUCCESS : EXIT_FAILURE)
}

if CommandLine.arguments.contains("--print-window-matches") {
    let sessions = SessionAggregator.aggregate(CodexSessionStore().loadSessions()).sessions
    let focuser = AgentWorkspaceWindowFocuser()
    guard let windows = focuser.windowSnapshotsForDiagnostics() else {
        print("not-trusted")
        exit(EXIT_FAILURE)
    }
    print("windows=\(windows.count) sessions=\(sessions.count)")
    for session in sessions {
        let match = AgentWorkspaceWindowMatcher.bestMatch(for: session, windows: windows)
        let windowText = match.map { "\($0.kind)\t\($0.window.appName)\t\($0.window.title)" } ?? "no-match"
        print("\(session.status.rawValue)\t\(session.displayName)\t\(session.summary)\t\(session.windowTitleHints.joined(separator: ","))\t\(windowText)")
    }
    exit(EXIT_SUCCESS)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
