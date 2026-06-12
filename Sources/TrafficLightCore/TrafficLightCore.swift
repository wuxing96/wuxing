import Foundation
import CoreGraphics

public enum TrafficLightPanelMode: Equatable, Sendable {
    case collapsed
    case expanded
}

public enum TrafficLightPanelHitRegion: Equatable, Sendable {
    case collapseButton
    case closeButton
    case resizeTopEdge
    case resizeBottomEdge
    case resizeLeftEdge
    case resizeRightEdge
    case resizeTopLeftCorner
    case resizeTopRightCorner
    case resizeBottomLeftCorner
    case resizeBottomRightCorner
    case dragHandle
    case content

    public var isResizeRegion: Bool {
        switch self {
        case .resizeTopEdge, .resizeBottomEdge, .resizeLeftEdge, .resizeRightEdge,
             .resizeTopLeftCorner, .resizeTopRightCorner, .resizeBottomLeftCorner, .resizeBottomRightCorner:
            return true
        case .collapseButton, .closeButton, .dragHandle, .content:
            return false
        }
    }

    public var resizesTop: Bool {
        self == .resizeTopEdge || self == .resizeTopLeftCorner || self == .resizeTopRightCorner
    }

    public var resizesBottom: Bool {
        self == .resizeBottomEdge || self == .resizeBottomLeftCorner || self == .resizeBottomRightCorner
    }

    public var resizesLeft: Bool {
        self == .resizeLeftEdge || self == .resizeTopLeftCorner || self == .resizeBottomLeftCorner
    }

    public var resizesRight: Bool {
        self == .resizeRightEdge || self == .resizeTopRightCorner || self == .resizeBottomRightCorner
    }
}

public enum TrafficLightPanelClickAction: Equatable, Sendable {
    case expand
    case collapse
    case requestClose
    case none
}

public enum TrafficLightSessionRowAction: Equatable, Sendable {
    case open
    case stop
}

public enum TrafficLightPanelInteraction {
    public static let expandedTitleHeight: CGFloat = 52
    public static let expandedCloseButtonSize: CGFloat = 22
    public static let expandedCloseButtonRightMargin: CGFloat = 16
    public static let expandedCloseButtonTopMargin: CGFloat = 16
    public static let expandedWindowButtonSpacing: CGFloat = 2
    public static let expandedResizeHandleSize: CGFloat = 24
    public static let expandedResizeEdgeThickness: CGFloat = 8

    public static func hitRegion(
        mode: TrafficLightPanelMode,
        point: CGPoint,
        bounds: CGRect
    ) -> TrafficLightPanelHitRegion {
        switch mode {
        case .collapsed:
            return .dragHandle
        case .expanded:
            if closeButtonRect(in: bounds).contains(point) {
                return .closeButton
            }
            if collapseButtonRect(in: bounds).contains(point) {
                return .collapseButton
            }
            if let resizeRegion = resizeHitRegion(point: point, bounds: bounds) {
                return resizeRegion
            }
            if point.y >= bounds.maxY - expandedTitleHeight {
                return .dragHandle
            }
            return .content
        }
    }

    public static func canStartDrag(
        mode: TrafficLightPanelMode,
        point: CGPoint,
        bounds: CGRect
    ) -> Bool {
        switch hitRegion(mode: mode, point: point, bounds: bounds) {
        case .dragHandle:
            return true
        case .collapseButton, .closeButton, .content:
            return false
        case .resizeTopEdge, .resizeBottomEdge, .resizeLeftEdge, .resizeRightEdge,
             .resizeTopLeftCorner, .resizeTopRightCorner, .resizeBottomLeftCorner, .resizeBottomRightCorner:
            return false
        }
    }

    public static func clickAction(
        mode: TrafficLightPanelMode,
        mouseDown: CGPoint,
        mouseUp: CGPoint,
        bounds: CGRect,
        movedDuringDrag: Bool
    ) -> TrafficLightPanelClickAction {
        guard !movedDuringDrag else {
            return .none
        }

        switch mode {
        case .collapsed:
            return .expand
        case .expanded:
            let downRegion = hitRegion(mode: mode, point: mouseDown, bounds: bounds)
            let upRegion = hitRegion(mode: mode, point: mouseUp, bounds: bounds)
            if downRegion == .collapseButton && upRegion == .collapseButton {
                return .collapse
            }
            if downRegion == .closeButton && upRegion == .closeButton {
                return .requestClose
            }
            return .none
        }
    }

    public static func closeButtonRect(in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.maxX - expandedCloseButtonRightMargin - expandedCloseButtonSize,
            y: bounds.maxY - expandedCloseButtonTopMargin - expandedCloseButtonSize,
            width: expandedCloseButtonSize,
            height: expandedCloseButtonSize
        )
    }

    public static func collapseButtonRect(in bounds: CGRect) -> CGRect {
        let closeRect = closeButtonRect(in: bounds)
        return CGRect(
            x: closeRect.minX - expandedWindowButtonSpacing - expandedCloseButtonSize,
            y: closeRect.minY,
            width: expandedCloseButtonSize,
            height: expandedCloseButtonSize
        )
    }

    public static func resizeHandleRect(in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.maxX - expandedResizeHandleSize,
            y: bounds.minY,
            width: expandedResizeHandleSize,
            height: expandedResizeHandleSize
        )
    }

    private static func resizeHitRegion(point: CGPoint, bounds: CGRect) -> TrafficLightPanelHitRegion? {
        let thickness = expandedResizeEdgeThickness
        let cornerSize = expandedResizeHandleSize
        let isCornerLeft = point.x <= bounds.minX + cornerSize
        let isCornerRight = point.x >= bounds.maxX - cornerSize
        let isCornerBottom = point.y <= bounds.minY + cornerSize
        let isCornerTop = point.y >= bounds.maxY - cornerSize

        switch (isCornerLeft, isCornerRight, isCornerTop, isCornerBottom) {
        case (true, false, true, false):
            return .resizeTopLeftCorner
        case (false, true, true, false):
            return .resizeTopRightCorner
        case (true, false, false, true):
            return .resizeBottomLeftCorner
        case (false, true, false, true):
            return .resizeBottomRightCorner
        default:
            break
        }

        let isLeft = point.x <= bounds.minX + thickness
        let isRight = point.x >= bounds.maxX - thickness
        let isBottom = point.y <= bounds.minY + thickness
        let isTop = point.y >= bounds.maxY - thickness

        switch (isLeft, isRight, isTop, isBottom) {
        case (true, false, false, false):
            return .resizeLeftEdge
        case (false, true, false, false):
            return .resizeRightEdge
        case (false, false, true, false):
            return .resizeTopEdge
        case (false, false, false, true):
            return .resizeBottomEdge
        default:
            return nil
        }
    }
}

public enum TrafficLightRefreshPolicy {
    public static let statusInterval: TimeInterval = 0.05
    public static let tokenUsageInterval: TimeInterval = 30
}

public enum TrafficLightWindowControlStyle {
    public static let visualDiameter: CGFloat = 12
}

public enum TrafficLightExpandedHeader {
    public static let title = "AI SESSIONS"
    public static let titleFontSize: CGFloat = 16
    public static let titleLineHeight: CGFloat = 22
    public static let countFontSize: CGFloat = titleFontSize
    public static let iconHeight: CGFloat = titleLineHeight
    public static let iconAssetName = "mushi-status-header"

    public static func countText(sessionCount: Int) -> String {
        "\(sessionCount)"
    }
}

public enum TrafficLightCollapsedStatusLayout {
    public static let statuses: [SessionStatus] = [.working, .waiting, .completed]
    public static let iconSize: CGFloat = 25
    public static let iconSpacing: CGFloat = 6
    public static let leadingInset: CGFloat = 8
    public static let countBadgeSize: CGFloat = 13

    public static func iconRect(index: Int, in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.minX + leadingInset + CGFloat(index) * (iconSize + iconSpacing),
            y: bounds.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
    }

    public static func countBadgeRect(for iconRect: CGRect) -> CGRect {
        CGRect(
            x: iconRect.maxX - countBadgeSize + 1,
            y: iconRect.minY - 1,
            width: countBadgeSize,
            height: countBadgeSize
        )
    }

    public static func assetName(for status: SessionStatus, count: Int) -> String {
        guard count > 0 else {
            return "mushi-status-idle"
        }
        switch status {
        case .working:
            return "mushi-status-working"
        case .waiting:
            return "mushi-status-waiting"
        case .completed:
            return "mushi-status-done"
        case .ended, .inactive:
            return "mushi-status-idle"
        }
    }
}

public enum TrafficLightExpandedListLayout {
    public static let defaultVisibleRows = 3

    public static func visibleRowCount(sessionCount: Int) -> Int {
        visibleRowCount(sessionCount: sessionCount, preferredVisibleRows: defaultVisibleRows)
    }

    public static func visibleRowCount(sessionCount: Int, preferredVisibleRows: Int) -> Int {
        max(1, min(sessionCount, max(1, preferredVisibleRows)))
    }

    public static func maxScrollOffset(
        sessionCount: Int,
        visibleRows: Int,
        rowHeight: CGFloat
    ) -> CGFloat {
        CGFloat(max(0, sessionCount - visibleRows)) * rowHeight
    }

    public static func clampedScrollOffset(
        _ offset: CGFloat,
        sessionCount: Int,
        visibleRows: Int,
        rowHeight: CGFloat
    ) -> CGFloat {
        max(0, min(offset, maxScrollOffset(sessionCount: sessionCount, visibleRows: visibleRows, rowHeight: rowHeight)))
    }

    public static func visibleRange(
        sessionCount: Int,
        visibleRows: Int,
        scrollOffset: CGFloat,
        rowHeight: CGFloat
    ) -> Range<Int> {
        guard sessionCount > 0, visibleRows > 0, rowHeight > 0 else {
            return 0..<0
        }
        let clampedOffset = clampedScrollOffset(
            scrollOffset,
            sessionCount: sessionCount,
            visibleRows: visibleRows,
            rowHeight: rowHeight
        )
        let start = min(sessionCount, max(0, Int(floor(clampedOffset / rowHeight))))
        return start..<min(sessionCount, start + visibleRows + 1)
    }

    public static func scrollOffsetPreservingAnchor<ID: Equatable>(
        oldIDs: [ID],
        newIDs: [ID],
        currentOffset: CGFloat,
        visibleRows: Int,
        rowHeight: CGFloat
    ) -> CGFloat {
        guard !oldIDs.isEmpty, !newIDs.isEmpty, rowHeight > 0 else {
            return 0
        }

        let oldOffset = clampedScrollOffset(
            currentOffset,
            sessionCount: oldIDs.count,
            visibleRows: visibleRows,
            rowHeight: rowHeight
        )
        let anchorIndex = min(oldIDs.count - 1, max(0, Int(floor(oldOffset / rowHeight))))
        let anchorID = oldIDs[anchorIndex]
        let intraRowOffset = oldOffset - CGFloat(anchorIndex) * rowHeight
        let proposedOffset: CGFloat
        if let newIndex = newIDs.firstIndex(of: anchorID) {
            proposedOffset = CGFloat(newIndex) * rowHeight + intraRowOffset
        } else {
            proposedOffset = oldOffset
        }

        return clampedScrollOffset(
            proposedOffset,
            sessionCount: newIDs.count,
            visibleRows: visibleRows,
            rowHeight: rowHeight
        )
    }
}

public enum TrafficLightPanelResize {
    public static func clampedSize(
        _ size: CGSize,
        minSize: CGSize,
        maxSize: CGSize
    ) -> CGSize {
        CGSize(
            width: min(max(size.width, minSize.width), maxSize.width),
            height: min(max(size.height, minSize.height), maxSize.height)
        )
    }
}

public enum TrafficLightSessionRowLayout {
    public static let actionButtonSize: CGFloat = 22
    public static let statusWidth: CGFloat = 56
    public static let statusFontSize: CGFloat = 10.5
    public static let actionFontSize: CGFloat = statusFontSize
    public static let openButtonWidth: CGFloat = statusWidth
    public static let stopButtonWidth: CGFloat = statusWidth
    public static let actionButtonSpacing: CGFloat = 5
    public static let actionTrailingInset: CGFloat = 8

    public static func statusPillRect(in row: CGRect) -> CGRect {
        CGRect(
            x: row.maxX - actionTrailingInset - statusWidth,
            y: row.maxY - 19,
            width: statusWidth,
            height: 15
        )
    }

    public static func relativeTimeRect(in row: CGRect) -> CGRect {
        let statusRect = statusPillRect(in: row)
        return CGRect(
            x: statusRect.minX,
            y: row.minY + 5,
            width: statusRect.width,
            height: 12
        )
    }

    public static func openButtonRect(in row: CGRect) -> CGRect {
        let statusRect = statusPillRect(in: row)
        return CGRect(
            x: statusRect.minX - actionButtonSpacing - openButtonWidth,
            y: statusRect.midY - actionButtonSize / 2,
            width: openButtonWidth,
            height: actionButtonSize
        )
    }

    public static func openButtonVisualRect(in row: CGRect) -> CGRect {
        let statusRect = statusPillRect(in: row)
        return CGRect(
            x: statusRect.minX - actionButtonSpacing - openButtonWidth,
            y: statusRect.minY,
            width: openButtonWidth,
            height: statusRect.height
        )
    }

    public static func stopButtonRect(in row: CGRect) -> CGRect {
        let openRect = openButtonRect(in: row)
        return CGRect(
            x: openRect.minX - actionButtonSpacing - stopButtonWidth,
            y: openRect.minY,
            width: stopButtonWidth,
            height: actionButtonSize
        )
    }

    public static func stopButtonVisualRect(in row: CGRect) -> CGRect {
        let openVisualRect = openButtonVisualRect(in: row)
        return CGRect(
            x: openVisualRect.minX - actionButtonSpacing - stopButtonWidth,
            y: openVisualRect.minY,
            width: stopButtonWidth,
            height: openVisualRect.height
        )
    }

    public static func contentTextWidth(in row: CGRect) -> CGFloat {
        max(24, stopButtonRect(in: row).minX - row.minX - 46)
    }

    public static func action(at point: CGPoint, in row: CGRect, canStop: Bool) -> TrafficLightSessionRowAction? {
        if openButtonRect(in: row).contains(point) {
            return .open
        }
        if canStop, stopButtonRect(in: row).contains(point) {
            return .stop
        }
        return nil
    }

    public static func verticalGapBetweenTimeAndStatus(in row: CGRect) -> CGFloat {
        statusPillRect(in: row).minY - relativeTimeRect(in: row).maxY
    }
}

public enum TrafficLightProduct {
    public static let displayName = "Mushi Signal"
}

public enum AgentSource: String, Codable, Equatable {
    case codex = "Codex"
    case claude = "Claude"
}

public enum SessionStatus: String, Codable, Equatable, Hashable, Comparable, Sendable {
    case inactive
    case ended
    case completed
    case working
    case waiting

    public var label: String {
        switch self {
        case .inactive:
            return "Idle"
        case .ended:
            return "Ended"
        case .completed:
            return "Done"
        case .working:
            return "Working"
        case .waiting:
            return "Waiting"
        }
    }

    public var sortPriority: Int {
        switch self {
        case .waiting:
            return 4
        case .working:
            return 3
        case .completed:
            return 1
        case .ended:
            return 0
        case .inactive:
            return -1
        }
    }

    public static func < (lhs: SessionStatus, rhs: SessionStatus) -> Bool {
        lhs.sortPriority < rhs.sortPriority
    }
}

public struct AIAgentSession: Equatable, Identifiable {
    public let id: String
    public let source: AgentSource
    public let projectName: String
    public var displayName: String
    public let cwd: String
    public let status: SessionStatus
    public let lastActivity: Date
    public let pendingToolCalls: Int
    public let summary: String
    public var windowTitleHints: [String]
    public var codexProcessID: Int?

    public init(
        id: String,
        source: AgentSource,
        projectName: String,
        displayName: String,
        cwd: String,
        status: SessionStatus,
        lastActivity: Date,
        pendingToolCalls: Int,
        summary: String,
        windowTitleHints: [String] = [],
        codexProcessID: Int? = nil
    ) {
        self.id = id
        self.source = source
        self.projectName = projectName
        self.displayName = displayName
        self.cwd = cwd
        self.status = status
        self.lastActivity = lastActivity
        self.pendingToolCalls = pendingToolCalls
        self.summary = summary
        self.windowTitleHints = windowTitleHints
        self.codexProcessID = codexProcessID
    }
}

public enum AgentWorkspaceWindowKind: Equatable, Sendable {
    case codexTerminal
    case ide
}

public struct AgentWorkspaceWindowSnapshot: Equatable, Sendable {
    public let appName: String
    public let title: String

    public init(appName: String, title: String) {
        self.appName = appName
        self.title = title
    }
}

public struct AgentWorkspaceWindowMatch: Equatable, Sendable {
    public let kind: AgentWorkspaceWindowKind
    public let window: AgentWorkspaceWindowSnapshot

    public init(kind: AgentWorkspaceWindowKind, window: AgentWorkspaceWindowSnapshot) {
        self.kind = kind
        self.window = window
    }
}

public struct RunningCodexProcess: Equatable, Sendable {
    public let pid: Int
    public let cwd: String
    public let windowTitleHints: [String]

    public init(pid: Int, cwd: String, windowTitleHints: [String] = []) {
        self.pid = pid
        self.cwd = cwd
        self.windowTitleHints = windowTitleHints
    }
}

public enum AgentWorkspaceWindowMatcher {
    private static let terminalAppNames = [
        "terminal",
        "iterm",
        "iterm2",
        "warp",
        "ghostty",
        "kitty",
        "alacritty",
        "终端"
    ]
    private static let ideAppNames = [
        "cursor",
        "visual studio code",
        "code",
        "windsurf",
        "intellij idea",
        "pycharm",
        "webstorm",
        "datagrip",
        "trae",
        "trae cn"
    ]

    public static func bestMatch(
        for session: AIAgentSession,
        windows: [AgentWorkspaceWindowSnapshot]
    ) -> AgentWorkspaceWindowMatch? {
        let windowTitleHints = session.windowTitleHints
            .map(normalized)
            .filter { !$0.isEmpty }
        if let terminal = windows.first(where: { isTerminalWindow($0) && titleMatches($0.title, keywords: windowTitleHints) }) {
            return AgentWorkspaceWindowMatch(kind: .codexTerminal, window: terminal)
        }

        let projectKeywords = keywords(for: session)
        guard !projectKeywords.isEmpty else {
            return nil
        }

        if let terminal = windows.first(where: { isTerminalWindow($0) && titleMatches($0.title, keywords: projectKeywords) }) {
            return AgentWorkspaceWindowMatch(kind: .codexTerminal, window: terminal)
        }
        if let ide = windows.first(where: { isIDEWindow($0) && titleMatches($0.title, keywords: projectKeywords) }) {
            return AgentWorkspaceWindowMatch(kind: .ide, window: ide)
        }
        return nil
    }

    private static func isTerminalWindow(_ window: AgentWorkspaceWindowSnapshot) -> Bool {
        let app = normalized(window.appName)
        return terminalAppNames.contains { app.contains($0) }
    }

    private static func isIDEWindow(_ window: AgentWorkspaceWindowSnapshot) -> Bool {
        let app = normalized(window.appName)
        return ideAppNames.contains { app == $0 || app.contains($0) }
    }

    private static func titleMatches(_ title: String, keywords: [String]) -> Bool {
        let normalizedTitle = normalized(title)
        return keywords.contains { normalizedTitle.contains($0) }
    }

    private static func keywords(for session: AIAgentSession) -> [String] {
        var result: [String] = []
        let normalizedCWD = RunningCodexProcesses.normalizedPath(session.cwd)
        let isHomeDirectorySession = normalizedCWD == RunningCodexProcesses.normalizedPath(NSHomeDirectory())
        var values = [
            session.projectName,
            session.displayName.components(separatedBy: " #").first ?? session.displayName
        ]
        if !isHomeDirectorySession {
            values.append(URL(fileURLWithPath: normalizedCWD).lastPathComponent)
            values.append(normalizedCWD)
        }

        for value in values {
            let keyword = normalized(value)
            if keyword.count >= 2, !result.contains(keyword) {
                result.append(keyword)
            }
        }
        return result
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

public struct SessionSummary: Equatable {
    public let status: SessionStatus
    public let sessions: [AIAgentSession]
    public let tokenUsage: TokenUsageSummary

    public init(status: SessionStatus, sessions: [AIAgentSession], tokenUsage: TokenUsageSummary = .empty) {
        self.status = status
        self.sessions = sessions
        self.tokenUsage = tokenUsage
    }
}

public struct TokenUsageSummary: Equatable, Sendable {
    public static let empty = TokenUsageSummary(
        totalTokens: 0,
        todayTokens: 0,
        creditBalance: nil,
        totalUsedPercent: nil,
        todayUsedPercent: nil,
        primaryUsedPercent: nil,
        primaryResetAt: nil,
        secondaryUsedPercent: nil,
        secondaryResetAt: nil,
        updatedAt: nil
    )

    public let totalTokens: Int
    public let todayTokens: Int
    public let creditBalance: TokenCreditBalance?
    public let totalUsedPercent: Double?
    public let todayUsedPercent: Double?
    public let primaryUsedPercent: Double?
    public let primaryResetAt: Date?
    public let secondaryUsedPercent: Double?
    public let secondaryResetAt: Date?
    public let updatedAt: Date?

    public init(
        totalTokens: Int,
        todayTokens: Int,
        creditBalance: TokenCreditBalance? = nil,
        totalUsedPercent: Double? = nil,
        todayUsedPercent: Double?,
        primaryUsedPercent: Double?,
        primaryResetAt: Date?,
        secondaryUsedPercent: Double?,
        secondaryResetAt: Date?,
        updatedAt: Date?
    ) {
        self.totalTokens = totalTokens
        self.todayTokens = todayTokens
        self.creditBalance = creditBalance
        self.totalUsedPercent = totalUsedPercent ?? secondaryUsedPercent ?? primaryUsedPercent
        self.todayUsedPercent = todayUsedPercent
        self.primaryUsedPercent = primaryUsedPercent
        self.primaryResetAt = primaryResetAt
        self.secondaryUsedPercent = secondaryUsedPercent
        self.secondaryResetAt = secondaryResetAt
        self.updatedAt = updatedAt
    }

    public var primaryRemainingPercent: Double? {
        primaryUsedPercent.map { min(100, max(0, 100 - $0)) }
    }

    public var secondaryRemainingPercent: Double? {
        secondaryUsedPercent.map { min(100, max(0, 100 - $0)) }
    }

    public var totalRemainingPercent: Double? {
        (secondaryUsedPercent ?? primaryUsedPercent).map { min(100, max(0, 100 - $0)) }
    }
}

public struct TokenCreditBalance: Equatable, Sendable {
    public let remaining: Double
    public let total: Double?
    public let currency: String?

    public init(remaining: Double, total: Double? = nil, currency: String? = nil) {
        self.remaining = remaining
        self.total = total
        self.currency = currency
    }
}

public struct TokenMetricDisplay: Equatable, Sendable {
    public let label: String
    public let primary: String
    public let secondary: String?

    public init(label: String, primary: String, secondary: String? = nil) {
        self.label = label
        self.primary = primary
        self.secondary = secondary
    }
}

public enum TrafficLightTokenDisplay {
    public static func weekly(_ usage: TokenUsageSummary) -> TokenMetricDisplay {
        if let remaining = usage.totalRemainingPercent {
            return TokenMetricDisplay(
                label: "Weekly quota",
                primary: "\(percentText(remaining)) left"
            )
        }
        if let creditBalance = usage.creditBalance {
            return TokenMetricDisplay(
                label: "API balance",
                primary: "\(formatCredits(creditBalance.remaining, currency: creditBalance.currency)) left"
            )
        }
        return TokenMetricDisplay(label: "Total remaining", primary: "--")
    }

    public static func today(_ usage: TokenUsageSummary) -> TokenMetricDisplay {
        if let todayUsedPercent = usage.todayUsedPercent {
            return TokenMetricDisplay(
                label: "Today usage",
                primary: "\(percentText(todayUsedPercent)) used",
                secondary: formatTokens(usage.todayTokens, includeUnit: true)
            )
        }
        guard usage.updatedAt != nil else {
            return TokenMetricDisplay(label: "Today usage", primary: "--")
        }
        return TokenMetricDisplay(
            label: "Today usage",
            primary: formatTokens(usage.todayTokens, includeUnit: true)
        )
    }

    public static func compactWeekly(_ usage: TokenUsageSummary) -> String {
        if let remaining = usage.totalRemainingPercent {
            return "Week \(percentText(remaining)) left"
        }
        if let creditBalance = usage.creditBalance {
            return "API \(formatCredits(creditBalance.remaining, currency: creditBalance.currency)) left"
        }
        return "Balance --"
    }

    public static func compactToday(_ usage: TokenUsageSummary) -> String {
        if let todayUsedPercent = usage.todayUsedPercent {
            return "Today \(percentText(todayUsedPercent)) used"
        }
        guard usage.updatedAt != nil else {
            return "Today --"
        }
        return "Today \(formatTokens(usage.todayTokens, includeUnit: false)) tok"
    }

    private static func percentText(_ percent: Double) -> String {
        if percent >= 10 {
            return "\(Int(percent.rounded()))%"
        }
        return String(format: "%.1f%%", percent)
    }

    private static func formatTokens(_ tokens: Int, includeUnit: Bool) -> String {
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

    private static func formatCredits(_ amount: Double, currency: String?) -> String {
        let value = String(format: "%.2f", amount)
        guard let currency, !currency.isEmpty else {
            return value
        }
        switch currency.uppercased() {
        case "USD", "$":
            return "$\(value)"
        case "CNY", "RMB", "¥":
            return "¥\(value)"
        default:
            return "\(value) \(currency.uppercased())"
        }
    }
}

public enum SessionAggregator {
    public static func aggregate(_ sessions: [AIAgentSession], tokenUsage: TokenUsageSummary = .empty) -> SessionSummary {
        var sorted = sessions.sorted { lhs, rhs in
            if lhs.status.sortPriority != rhs.status.sortPriority {
                return lhs.status.sortPriority > rhs.status.sortPriority
            }
            return lhs.lastActivity > rhs.lastActivity
        }

        let projectCounts = Dictionary(grouping: sorted, by: \.projectName)
            .mapValues(\.count)
        var seenProjects: [String: Int] = [:]

        sorted = sorted.map { session in
            var updated = session
            if projectCounts[session.projectName, default: 0] > 1 {
                let next = seenProjects[session.projectName, default: 0] + 1
                seenProjects[session.projectName] = next
                updated.displayName = "\(session.projectName) #\(next)"
            }
            return updated
        }

        return SessionSummary(
            status: sorted.map(\.status).max() ?? .inactive,
            sessions: sorted,
            tokenUsage: tokenUsage
        )
    }
}

public enum CodexTokenUsageParser {
    private struct TokenEvent {
        let timestamp: Date
        let tokens: Int
    }

    public static func parse(
        lines: [String],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TokenUsageSummary {
        var todayTokens = 0
        var tokenEvents: [TokenEvent] = []
        var latestTokenTimestamp: Date?
        var latestQuotaTimestamp: Date?
        var latestCreditTimestamp: Date?
        var latestPrimaryUsedPercent: Double?
        var latestPrimaryResetAt: Date?
        var latestPrimaryWindowMinutes: Double?
        var latestSecondaryUsedPercent: Double?
        var latestSecondaryResetAt: Date?
        var latestSecondaryWindowMinutes: Double?
        var latestCreditBalance: TokenCreditBalance?

        for line in lines where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let event = parseJSONLine(line),
                  event["type"] as? String == "event_msg",
                  let timestampString = event["timestamp"] as? String,
                  let timestamp = codexDate(from: timestampString),
                  let payload = event["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count" else {
                continue
            }

            if let info = payload["info"] as? [String: Any],
               let lastUsage = info["last_token_usage"] as? [String: Any],
               let tokens = intValue(lastUsage["total_tokens"]) {
                tokenEvents.append(TokenEvent(timestamp: timestamp, tokens: tokens))
                if calendar.isDate(timestamp, inSameDayAs: now) {
                    todayTokens += tokens
                }
            }

            let rateLimits = payload["rate_limits"] as? [String: Any]
            let primary = rateLimits?["primary"] as? [String: Any]
            let secondary = rateLimits?["secondary"] as? [String: Any]

            if latestTokenTimestamp == nil || timestamp >= latestTokenTimestamp! {
                latestTokenTimestamp = timestamp
            }

            if shouldUseRateLimitForQuota(rateLimits: rateLimits, primary: primary, secondary: secondary, now: now),
               latestQuotaTimestamp == nil || timestamp >= latestQuotaTimestamp! {
                latestQuotaTimestamp = timestamp
                latestPrimaryUsedPercent = doubleValue(primary?["used_percent"])
                latestPrimaryResetAt = unixDate(primary?["resets_at"])
                latestPrimaryWindowMinutes = doubleValue(primary?["window_minutes"])
                latestSecondaryUsedPercent = doubleValue(secondary?["used_percent"])
                latestSecondaryResetAt = unixDate(secondary?["resets_at"])
                latestSecondaryWindowMinutes = doubleValue(secondary?["window_minutes"])
            }

            if let creditBalance = creditBalance(from: rateLimits?["credits"]),
               latestCreditTimestamp == nil || timestamp >= latestCreditTimestamp! {
                latestCreditTimestamp = timestamp
                latestCreditBalance = creditBalance
            }
        }

        let useAPIBilling = latestCreditBalance != nil
            && latestCreditTimestamp.map { creditTimestamp in
                latestQuotaTimestamp == nil || creditTimestamp >= latestQuotaTimestamp!
            } == true
        if useAPIBilling {
            latestPrimaryUsedPercent = nil
            latestPrimaryResetAt = nil
            latestPrimaryWindowMinutes = nil
            latestSecondaryUsedPercent = nil
            latestSecondaryResetAt = nil
            latestSecondaryWindowMinutes = nil
        } else {
            latestCreditBalance = nil
        }

        let limitWindowTokens = currentLimitWindowTokens(
            from: tokenEvents,
            now: now,
            resetAt: latestSecondaryResetAt ?? latestPrimaryResetAt,
            windowMinutes: latestSecondaryWindowMinutes ?? latestPrimaryWindowMinutes
        )
        let weekTokens = currentWeekTokens(from: tokenEvents, now: now, calendar: calendar)
        let totalUsedPercent = latestSecondaryUsedPercent ?? latestPrimaryUsedPercent
        let todayUsedPercent = estimatedUsagePercent(
            tokens: todayTokens,
            totalTokens: limitWindowTokens,
            totalUsedPercent: latestSecondaryUsedPercent ?? latestPrimaryUsedPercent
        )

        return TokenUsageSummary(
            totalTokens: weekTokens,
            todayTokens: todayTokens,
            creditBalance: latestCreditBalance,
            totalUsedPercent: totalUsedPercent,
            todayUsedPercent: todayUsedPercent,
            primaryUsedPercent: latestPrimaryUsedPercent,
            primaryResetAt: latestPrimaryResetAt,
            secondaryUsedPercent: latestSecondaryUsedPercent,
            secondaryResetAt: latestSecondaryResetAt,
            updatedAt: latestTokenTimestamp
        )
    }

    private static func parseJSONLine(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    private static func codexDate(from value: String) -> Date? {
        ISO8601DateFormatter.codex.date(from: value)
            ?? ISO8601DateFormatter.basic.date(from: value)
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return nil
    }

    private static func unixDate(_ value: Any?) -> Date? {
        doubleValue(value).map { Date(timeIntervalSince1970: $0) }
    }

    private static func shouldUseRateLimitForQuota(
        rateLimits: [String: Any]?,
        primary: [String: Any]?,
        secondary: [String: Any]?,
        now: Date
    ) -> Bool {
        guard primary != nil || secondary != nil else {
            return false
        }

        let primaryResetAt = unixDate(primary?["resets_at"])
        let secondaryResetAt = unixDate(secondary?["resets_at"])
        guard primaryResetAt.map({ $0 > now }) == true || secondaryResetAt.map({ $0 > now }) == true else {
            return false
        }

        if let limitID = rateLimits?["limit_id"] as? String,
           limitID != "codex" {
            return false
        }

        return true
    }

    private static func creditBalance(from value: Any?) -> TokenCreditBalance? {
        guard let dictionary = value as? [String: Any] else {
            return nil
        }
        let total = firstDouble(
            in: dictionary,
            keys: ["total", "limit", "granted", "total_credits", "credit_limit", "initial"]
        )
        let used = firstDouble(
            in: dictionary,
            keys: ["used", "consumed", "spent", "used_credits", "amount_used"]
        )
        let usedPercent = firstDouble(
            in: dictionary,
            keys: ["used_percent", "usage_percent", "percent_used"]
        )
        let remaining = firstDouble(
            in: dictionary,
            keys: ["remaining", "balance", "available", "total_remaining", "remaining_credits", "amount_remaining"]
        ) ?? total.flatMap { total in
            if let used {
                return max(0, total - used)
            }
            if let usedPercent {
                return max(0, total * (100 - usedPercent) / 100)
            }
            return nil
        }

        guard let remaining else {
            return nil
        }
        return TokenCreditBalance(
            remaining: remaining,
            total: total,
            currency: firstString(in: dictionary, keys: ["currency", "unit"])
        )
    }

    private static func firstDouble(in dictionary: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = doubleValue(dictionary[key]) {
                return value
            }
        }
        return nil
    }

    private static func firstString(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func currentLimitWindowTokens(
        from events: [TokenEvent],
        now: Date,
        resetAt: Date?,
        windowMinutes: Double?
    ) -> Int {
        guard let resetAt,
              let windowMinutes,
              windowMinutes > 0 else {
            return 0
        }

        let windowStart = resetAt.addingTimeInterval(-windowMinutes * 60)
        return events
            .filter { $0.timestamp >= windowStart && $0.timestamp <= now }
            .reduce(0) { $0 + $1.tokens }
    }

    private static func currentWeekTokens(
        from events: [TokenEvent],
        now: Date,
        calendar: Calendar
    ) -> Int {
        let weekStart = localMondayWeekStart(for: now, calendar: calendar)
        return events
            .filter { $0.timestamp >= weekStart && $0.timestamp <= now }
            .reduce(0) { $0 + $1.tokens }
    }

    private static func localMondayWeekStart(for date: Date, calendar: Calendar) -> Date {
        let startOfToday = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfToday)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfToday) ?? startOfToday
    }

    private static func estimatedUsagePercent(
        tokens: Int,
        totalTokens: Int,
        totalUsedPercent: Double?
    ) -> Double? {
        guard tokens > 0,
              totalTokens > 0,
              let totalUsedPercent,
              totalUsedPercent > 0 else {
            return nil
        }

        let estimatedLimitTokens = Double(totalTokens) / (totalUsedPercent / 100)
        return Double(tokens) / estimatedLimitTokens * 100
    }
}

public enum CodexSessionFileReader {
    public static let defaultHeadByteLimit = 16 * 1_024
    public static let defaultTailByteLimit = 256 * 1_024
    private static let maximumMetadataLineByteLimit = 2 * 1_024 * 1_024

    public static func statusLines(
        fileURL: URL,
        headByteLimit: Int = defaultHeadByteLimit,
        tailByteLimit: Int = defaultTailByteLimit
    ) -> [String] {
        guard let fileSize = size(of: fileURL), fileSize > 0 else {
            return []
        }

        let fullReadLimit = max(0, headByteLimit) + max(0, tailByteLimit)
        if fileSize <= UInt64(fullReadLimit),
           let contents = try? String(contentsOf: fileURL, encoding: .utf8) {
            return splitLines(contents)
        }

        let headLines = leadingMetadataLines(
            fileURL: fileURL,
            fileSize: fileSize,
            headByteLimit: headByteLimit
        )
        let tailLength = min(max(0, tailByteLimit), Int(fileSize))
        let tailOffset = max(0, Int(fileSize) - tailLength)
        let tailLines = readLines(
            fileURL: fileURL,
            offset: UInt64(tailOffset),
            length: tailLength,
            droppingLeadingPartial: tailOffset > 0,
            droppingTrailingPartial: false
        )

        return headLines + tailLines
    }

    public static func metadataLines(
        fileURL: URL,
        headByteLimit: Int = defaultHeadByteLimit
    ) -> [String] {
        guard let fileSize = size(of: fileURL), fileSize > 0 else {
            return []
        }
        return leadingMetadataLines(
            fileURL: fileURL,
            fileSize: fileSize,
            headByteLimit: headByteLimit
        )
    }

    public static func cwd(
        fileURL: URL,
        headByteLimit: Int = defaultHeadByteLimit
    ) -> String? {
        cwd(in: metadataLines(fileURL: fileURL, headByteLimit: headByteLimit))
    }

    private static func size(of fileURL: URL) -> UInt64? {
        guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = values.fileSize else {
            return nil
        }
        return UInt64(fileSize)
    }

    private static func readLines(
        fileURL: URL,
        offset: UInt64,
        length: Int,
        droppingLeadingPartial: Bool,
        droppingTrailingPartial: Bool
    ) -> [String] {
        guard length > 0,
              let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return []
        }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: offset)
            let data = handle.readData(ofLength: length)
            guard var text = String(data: data, encoding: .utf8) else {
                return []
            }

            if droppingLeadingPartial {
                guard let newline = text.firstIndex(of: "\n") else {
                    return []
                }
                text = String(text[text.index(after: newline)...])
            }

            if droppingTrailingPartial, !text.hasSuffix("\n") {
                guard let newline = text.lastIndex(of: "\n") else {
                    return []
                }
                text = String(text[..<newline])
            }

            return splitLines(text)
        } catch {
            return []
        }
    }

    private static func leadingMetadataLines(
        fileURL: URL,
        fileSize: UInt64,
        headByteLimit: Int
    ) -> [String] {
        let headLines = readLines(
            fileURL: fileURL,
            offset: 0,
            length: min(max(0, headByteLimit), Int(fileSize)),
            droppingLeadingPartial: false,
            droppingTrailingPartial: true
        )
        let metadata = metadataLines(in: headLines)
        if !metadata.isEmpty {
            return metadata
        }
        guard let firstLine = firstCompleteLine(fileURL: fileURL),
              isMetadataLine(firstLine) else {
            return []
        }
        return [firstLine]
    }

    private static func firstCompleteLine(fileURL: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return nil
        }
        defer { try? handle.close() }

        var data = Data()
        let chunkSize = 16 * 1_024
        while data.count < maximumMetadataLineByteLimit {
            let remaining = maximumMetadataLineByteLimit - data.count
            let chunk = handle.readData(ofLength: min(chunkSize, remaining))
            if chunk.isEmpty {
                break
            }
            if let newline = chunk.firstIndex(of: 0x0A) {
                data.append(chunk[..<newline])
                break
            }
            data.append(chunk)
        }

        guard !data.isEmpty,
              let line = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func splitLines(_ text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func metadataLines(in lines: [String]) -> [String] {
        lines.filter(isMetadataLine)
    }

    private static func isMetadataLine(_ line: String) -> Bool {
        line.contains(#""session_meta""#) || line.contains(#""turn_context""#)
    }

    private static func cwd(in lines: [String]) -> String? {
        var cwd: String?
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            let type = object["type"] as? String
            let payload = object["payload"] as? [String: Any]
            if type == "session_meta", let value = payload?["cwd"] as? String {
                cwd = value
            } else if type == "turn_context", let value = payload?["cwd"] as? String {
                cwd = value
            }
        }
        return cwd
    }
}

public enum CodexSessionParser {
    private struct PendingApprovalCall {
        let command: String?
    }

    public static func parse(
        lines: [String],
        filePath: String,
        now: Date = Date(),
        runningProcessCommands: [String] = []
    ) throws -> AIAgentSession {
        var id = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
        var cwd = NSHomeDirectory()
        var lastActivity = Date(timeIntervalSince1970: 0)
        var lastMessageSummary = ""
        var lastMeaningfulEvent = "session"
        var pendingCalls: Set<String> = []
        var pendingCallOrder: [String] = []
        var pendingCallSummaries: [String: String] = [:]
        var pendingApprovalCalls: [String: PendingApprovalCall] = [:]
        var pendingEditApprovalCalls: Set<String> = []
        var waitingForUser = false

        for line in lines where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let event = parseJSONLine(line) else {
                continue
            }

            if let timestamp = event["timestamp"] as? String,
               let parsedDate = ISO8601DateFormatter.codex.date(from: timestamp) {
                lastActivity = parsedDate
            }

            let type = event["type"] as? String
            let payload = event["payload"] as? [String: Any]

            if type == "session_meta" {
                if let payloadID = payload?["id"] as? String {
                    id = payloadID
                }
                if let payloadCWD = payload?["cwd"] as? String {
                    cwd = payloadCWD
                }
                continue
            }

            if type == "turn_context" {
                if let turnCWD = payload?["cwd"] as? String {
                    cwd = turnCWD
                }
                continue
            }

            if type == "event_msg" {
                let eventType = payload?["type"] as? String
                switch eventType {
                case "agent_message":
                    lastMeaningfulEvent = "assistant_commentary"
                    lastMessageSummary = payload?["message"] as? String ?? "Working"
                case "patch_apply_end":
                    if let callID = payload?["call_id"] as? String {
                        pendingEditApprovalCalls.remove(callID)
                    }
                    lastMeaningfulEvent = "custom_tool_call_output"
                    lastMessageSummary = "Editing files"
                case "turn_aborted":
                    pendingCalls.removeAll()
                    pendingCallOrder.removeAll()
                    pendingCallSummaries.removeAll()
                    pendingApprovalCalls.removeAll()
                    pendingEditApprovalCalls.removeAll()
                    waitingForUser = false
                    lastMeaningfulEvent = "turn_aborted"
                    lastMessageSummary = "Canceled"
                case "task_complete":
                    pendingCalls.removeAll()
                    pendingCallOrder.removeAll()
                    pendingCallSummaries.removeAll()
                    pendingApprovalCalls.removeAll()
                    pendingEditApprovalCalls.removeAll()
                    waitingForUser = false
                    lastMeaningfulEvent = "task_complete"
                    lastMessageSummary = "Reply ready"
                default:
                    break
                }
                continue
            }

            guard type == "response_item" else {
                continue
            }

            let payloadType = payload?["type"] as? String
            switch payloadType {
            case "function_call":
                let functionName = payload?["name"] as? String ?? "tool"
                let callID = payload?["call_id"] as? String ?? UUID().uuidString
                let arguments = payload?["arguments"] as? String
                let command = commandString(from: arguments)
                pendingCalls.insert(callID)
                if !pendingCallOrder.contains(callID) {
                    pendingCallOrder.append(callID)
                }
                pendingCallSummaries[callID] = command ?? functionName
                lastMeaningfulEvent = "function_call"
                lastMessageSummary = command ?? functionName
                if functionName == "request_user_input" {
                    waitingForUser = true
                }
                if requiresEscalatedApproval(arguments) {
                    pendingApprovalCalls[callID] = PendingApprovalCall(command: command)
                    lastMessageSummary = command ?? functionName
                }

            case "function_call_output":
                if let callID = payload?["call_id"] as? String {
                    pendingCalls.remove(callID)
                    pendingCallOrder.removeAll { $0 == callID }
                    pendingCallSummaries.removeValue(forKey: callID)
                    pendingApprovalCalls.removeValue(forKey: callID)
                }
                if pendingCalls.isEmpty {
                    waitingForUser = false
                }
                lastMeaningfulEvent = "function_call_output"
                lastMessageSummary = "Tool output"

            case "custom_tool_call":
                let toolName = payload?["name"] as? String ?? "tool"
                let callID = payload?["call_id"] as? String ?? UUID().uuidString
                pendingCalls.insert(callID)
                if !pendingCallOrder.contains(callID) {
                    pendingCallOrder.append(callID)
                }
                pendingCallSummaries[callID] = customToolSummary(toolName)
                if toolName == "apply_patch" {
                    pendingEditApprovalCalls.insert(callID)
                }
                lastMeaningfulEvent = "custom_tool_call"
                lastMessageSummary = customToolSummary(toolName)

            case "custom_tool_call_output":
                if let callID = payload?["call_id"] as? String {
                    pendingCalls.remove(callID)
                    pendingCallOrder.removeAll { $0 == callID }
                    pendingCallSummaries.removeValue(forKey: callID)
                    pendingEditApprovalCalls.remove(callID)
                }
                if pendingCalls.isEmpty {
                    waitingForUser = false
                }
                lastMeaningfulEvent = "custom_tool_call_output"
                lastMessageSummary = "Tool output"

            case "message":
                let role = payload?["role"] as? String
                if role == "user" {
                    pendingCalls.removeAll()
                    pendingCallOrder.removeAll()
                    pendingCallSummaries.removeAll()
                    pendingApprovalCalls.removeAll()
                    pendingEditApprovalCalls.removeAll()
                    waitingForUser = false
                    lastMeaningfulEvent = "user_message"
                    lastMessageSummary = "New request"
                } else if role == "assistant" {
                    if payload?["phase"] as? String == "final_answer" {
                        pendingCalls.removeAll()
                        pendingCallOrder.removeAll()
                        pendingCallSummaries.removeAll()
                        pendingApprovalCalls.removeAll()
                        pendingEditApprovalCalls.removeAll()
                        waitingForUser = false
                        lastMeaningfulEvent = "assistant_message"
                        lastMessageSummary = firstText(in: payload) ?? "Reply ready"
                    } else {
                        lastMeaningfulEvent = "assistant_commentary"
                        lastMessageSummary = firstText(in: payload) ?? "Working"
                    }
                }

            case "web_search_call":
                lastMeaningfulEvent = "web_search_call"
                lastMessageSummary = "Searching"

            case "reasoning":
                lastMeaningfulEvent = "reasoning"
                lastMessageSummary = "Thinking"

            default:
                break
            }
        }

        let projectName = projectNameFromCWD(cwd)
        let status = statusFor(
            lastMeaningfulEvent: lastMeaningfulEvent,
            pendingCalls: pendingCalls.count,
            pendingApprovalCalls: Array(pendingApprovalCalls.values),
            pendingEditApprovals: pendingEditApprovalCalls.count,
            runningProcessCommands: runningProcessCommands,
            waitingForUser: waitingForUser,
            lastActivity: lastActivity,
            now: now
        )
        let summary = statusSummary(
            status: status,
            waitingForUser: waitingForUser,
            pendingApprovalCalls: Array(pendingApprovalCalls.values),
            pendingEditApprovals: pendingEditApprovalCalls.count,
            runningProcessCommands: runningProcessCommands,
            pendingCallSummaries: pendingCallOrder.compactMap { pendingCallSummaries[$0] },
            fallback: lastMessageSummary
        )

        return AIAgentSession(
            id: id,
            source: .codex,
            projectName: projectName,
            displayName: projectName,
            cwd: cwd,
            status: status,
            lastActivity: lastActivity,
            pendingToolCalls: pendingCalls.count,
            summary: summary
        )
    }

    public static func parse(
        fileURL: URL,
        now: Date = Date(),
        runningProcessCommands: [String] = []
    ) -> AIAgentSession? {
        let lines = CodexSessionFileReader.statusLines(fileURL: fileURL)
        guard !lines.isEmpty else {
            return nil
        }
        return try? parse(
            lines: lines,
            filePath: fileURL.path,
            now: now,
            runningProcessCommands: runningProcessCommands
        )
    }

    private static func parseJSONLine(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    private static func statusFor(
        lastMeaningfulEvent: String,
        pendingCalls: Int,
        pendingApprovalCalls: [PendingApprovalCall],
        pendingEditApprovals: Int,
        runningProcessCommands: [String],
        waitingForUser: Bool,
        lastActivity: Date,
        now: Date
    ) -> SessionStatus {
        if waitingForUser {
            return .waiting
        }
        if pendingEditApprovals > 0 {
            return .waiting
        }
        if pendingApprovalCalls.contains(where: { !approvalCallIsRunning($0, runningProcessCommands: runningProcessCommands) }) {
            return .waiting
        }
        if !pendingApprovalCalls.isEmpty {
            return .working
        }
        if pendingCalls > 0 {
            return .working
        }

        let age = now.timeIntervalSince(lastActivity)
        if age > 8 * 60 * 60 {
            return .inactive
        }

        switch lastMeaningfulEvent {
        case "user_message", "assistant_commentary", "reasoning", "function_call", "function_call_output", "custom_tool_call", "custom_tool_call_output", "web_search_call":
            return .working
        case "assistant_message", "turn_aborted", "task_complete":
            return .completed
        default:
            return .completed
        }
    }

    private static func statusSummary(
        status: SessionStatus,
        waitingForUser: Bool,
        pendingApprovalCalls: [PendingApprovalCall],
        pendingEditApprovals: Int,
        runningProcessCommands: [String],
        pendingCallSummaries: [String],
        fallback: String
    ) -> String {
        if waitingForUser {
            return "Needs your input"
        }
        if status == .waiting && pendingEditApprovals > 0 {
            return "Waiting for edit approval"
        }
        if status == .waiting && !pendingApprovalCalls.isEmpty {
            return "Waiting for approval"
        }
        if status == .working,
           let command = pendingApprovalCalls.first(where: { approvalCallIsRunning($0, runningProcessCommands: runningProcessCommands) })?.command {
            return command
        }
        if status == .working,
           let pendingSummary = pendingCallSummaries.last,
           !pendingSummary.isEmpty {
            return pendingSummary
        }
        if !fallback.isEmpty {
            return fallback
        }
        return status.label
    }

    private static func projectNameFromCWD(_ cwd: String) -> String {
        let expanded = (cwd as NSString).expandingTildeInPath
        if expanded == NSHomeDirectory() {
            return "~"
        }
        return URL(fileURLWithPath: expanded).lastPathComponent
    }

    private static func firstText(in payload: [String: Any]?) -> String? {
        guard let content = payload?["content"] as? [[String: Any]] else {
            return nil
        }
        for item in content {
            if let text = item["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func requiresEscalatedApproval(_ arguments: String?) -> Bool {
        guard let arguments else {
            return false
        }

        if let data = arguments.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           object["sandbox_permissions"] as? String == "require_escalated" {
            return true
        }

        return arguments.contains(#""sandbox_permissions":"require_escalated""#)
            || arguments.contains(#""sandbox_permissions": "require_escalated""#)
    }

    private static func commandString(from arguments: String?) -> String? {
        guard let arguments,
              let data = arguments.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let command = object["cmd"] as? String else {
            return nil
        }
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func customToolSummary(_ toolName: String) -> String {
        if toolName == "apply_patch" {
            return "Editing files"
        }
        return toolName
    }

    private static func approvalCallIsRunning(
        _ call: PendingApprovalCall,
        runningProcessCommands: [String]
    ) -> Bool {
        guard let command = call.command else {
            return false
        }
        return runningProcessCommands.contains { processCommandMatches($0, command: command) }
    }

    private static func processCommandMatches(_ processCommand: String, command: String) -> Bool {
        let command = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            return false
        }
        if processCommand.contains(command) {
            return true
        }

        let parts = command.split(whereSeparator: \.isWhitespace).map(String.init)
        let usefulParts = parts.filter { part in
            part.contains("/") || part.hasSuffix(".sh") || part.count >= 8
        }
        return usefulParts.contains { processCommand.contains($0) }
    }
}

private final class CodexSessionStatusCache: @unchecked Sendable {
    private struct Key: Hashable {
        let path: String
        let processFingerprint: Int
    }

    private struct Entry {
        let modified: Date
        let fileSize: Int
        let session: AIAgentSession
    }

    private let lock = NSLock()
    private var entries: [Key: Entry] = [:]

    func session(
        fileURL: URL,
        modified: Date,
        fileSize: Int,
        now: Date,
        runningProcessCommands: [String],
        processFingerprint: Int
    ) -> AIAgentSession? {
        let key = Key(path: fileURL.path, processFingerprint: processFingerprint)
        lock.lock()
        if let entry = entries[key],
           entry.modified == modified,
           entry.fileSize == fileSize {
            lock.unlock()
            return entry.session
        }
        lock.unlock()

        guard let session = CodexSessionParser.parse(
            fileURL: fileURL,
            now: now,
            runningProcessCommands: runningProcessCommands
        ) else {
            return nil
        }

        lock.lock()
        entries[key] = Entry(modified: modified, fileSize: fileSize, session: session)
        if entries.count > 128 {
            entries.removeAll(keepingCapacity: true)
            entries[key] = Entry(modified: modified, fileSize: fileSize, session: session)
        }
        lock.unlock()
        return session
    }
}

public struct CodexSessionStore: Sendable {
    public static let defaultRecentWindow: TimeInterval = 7 * 24 * 60 * 60
    public static let defaultEndedRetention: TimeInterval = 30 * 60

    public let root: URL
    public let recentWindow: TimeInterval
    public let endedRetention: TimeInterval
    private let sessionCache = CodexSessionStatusCache()

    public init(
        root: URL = URL(fileURLWithPath: "\(NSHomeDirectory())/.codex/sessions"),
        recentWindow: TimeInterval = Self.defaultRecentWindow,
        endedRetention: TimeInterval = Self.defaultEndedRetention
    ) {
        self.root = root
        self.recentWindow = recentWindow
        self.endedRetention = endedRetention
    }

    public func loadSessions(now: Date = Date()) -> [AIAgentSession] {
        let runningProcessCommands = RunningProcessCommands.snapshot()
        let activeSessions = RunningCodexProcesses.activeSessions()
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let processFingerprint = RunningProcessCommands.fingerprint(runningProcessCommands)
        var candidates: [(fileURL: URL, modified: Date, fileSize: Int)] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
            guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modified = values.contentModificationDate,
                  let fileSize = values.fileSize,
                  now.timeIntervalSince(modified) <= recentWindow else {
                continue
            }
            candidates.append((fileURL, modified, fileSize))
        }

        let sortedCandidates = candidates.sorted { $0.modified > $1.modified }

        let sessions = sortedCandidates.compactMap { candidate -> AIAgentSession? in
            guard let session = sessionCache.session(
                fileURL: candidate.fileURL,
                modified: candidate.modified,
                fileSize: candidate.fileSize,
                now: now,
                runningProcessCommands: runningProcessCommands,
                processFingerprint: processFingerprint
            ) else {
                return nil
            }
            if activeSessions == nil && session.status == .inactive {
                return nil
            }
            return session
        }

        guard let activeSessions else {
            return sessions
        }

        return Self.filterLiveSessions(
            sessions,
            activeSessions: activeSessions,
            now: now,
            endedRetention: endedRetention
        )
    }

    public static func filterLiveSessions(
        _ sessions: [AIAgentSession],
        activeSessionCountsByCWD: [String: Int]
    ) -> [AIAgentSession] {
        let normalizedActiveCounts = activeSessionCountsByCWD.reduce(into: [String: Int]()) { result, item in
            result[RunningCodexProcesses.normalizedPath(item.key), default: 0] += item.value
        }
        var keptCountsByCWD: [String: Int] = [:]

        return sessions
            .sorted { $0.lastActivity > $1.lastActivity }
            .filter { session in
                let cwd = RunningCodexProcesses.normalizedPath(session.cwd)
                let allowedCount = normalizedActiveCounts[cwd, default: 0]
                let keptCount = keptCountsByCWD[cwd, default: 0]
                guard keptCount < allowedCount else {
                    return false
                }
                keptCountsByCWD[cwd] = keptCount + 1
                return true
            }
    }

    public static func filterLiveSessions(
        _ sessions: [AIAgentSession],
        activeSessions: [RunningCodexProcess],
        now: Date = Date(),
        endedRetention: TimeInterval = Self.defaultEndedRetention
    ) -> [AIAgentSession] {
        var activeSessionsByCWD = Dictionary(grouping: activeSessions) { process in
            RunningCodexProcesses.normalizedPath(process.cwd)
        }.mapValues { processes in
            processes.sorted { $0.pid > $1.pid }
        }

        var result: [AIAgentSession] = []
        for session in sessions.sorted(by: { $0.lastActivity > $1.lastActivity }) {
            let cwd = RunningCodexProcesses.normalizedPath(session.cwd)
            guard var processes = activeSessionsByCWD[cwd],
                  !processes.isEmpty else {
                if now.timeIntervalSince(session.lastActivity) <= endedRetention {
                    result.append(endedSession(from: session))
                }
                continue
            }

            let process = processes.removeFirst()
            activeSessionsByCWD[cwd] = processes
            var updated = session
            if updated.status == .inactive {
                updated = idleLiveSession(from: updated)
            }
            updated.windowTitleHints = process.windowTitleHints
            updated.codexProcessID = process.pid
            result.append(updated)
        }
        return sortForDisplay(result)
    }

    private static func endedSession(from session: AIAgentSession) -> AIAgentSession {
        AIAgentSession(
            id: session.id,
            source: session.source,
            projectName: session.projectName,
            displayName: session.displayName,
            cwd: session.cwd,
            status: .ended,
            lastActivity: session.lastActivity,
            pendingToolCalls: 0,
            summary: "Codex process ended",
            windowTitleHints: [],
            codexProcessID: nil
        )
    }

    private static func idleLiveSession(from session: AIAgentSession) -> AIAgentSession {
        AIAgentSession(
            id: session.id,
            source: session.source,
            projectName: session.projectName,
            displayName: session.displayName,
            cwd: session.cwd,
            status: .completed,
            lastActivity: session.lastActivity,
            pendingToolCalls: 0,
            summary: "Idle",
            windowTitleHints: session.windowTitleHints,
            codexProcessID: session.codexProcessID
        )
    }

    private static func sortForDisplay(_ sessions: [AIAgentSession]) -> [AIAgentSession] {
        sessions.sorted { lhs, rhs in
            if lhs.status.sortPriority != rhs.status.sortPriority {
                return lhs.status.sortPriority > rhs.status.sortPriority
            }
            return lhs.lastActivity > rhs.lastActivity
        }
    }

    public func loadTokenUsage(now: Date = Date(), calendar: Calendar = .current) -> TokenUsageSummary {
        guard let earliestRelevantDate = calendar.date(
            byAdding: .day,
            value: -8,
            to: now
        ),
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return .empty
        }

        var lines: [String] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
            guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate,
                  modified >= earliestRelevantDate,
                  let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }
            lines.append(contentsOf: contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        }

        return CodexTokenUsageParser.parse(lines: lines, now: now, calendar: calendar)
    }
}

public enum RunningCodexProcesses {
    public static func activeSessionCounts() -> [String: Int]? {
        guard let sessions = activeSessions() else {
            return nil
        }

        return sessions.reduce(into: [String: Int]()) { result, session in
            result[normalizedPath(session.cwd), default: 0] += 1
        }
    }

    public static func activeSessions() -> [RunningCodexProcess]? {
        guard let psOutput = runProcess(executable: "/bin/ps", arguments: ["-axo", "pid,ppid,command"]) else {
            return nil
        }

        let pids = nativeCodexPIDs(from: psOutput)
        if pids.isEmpty {
            return []
        }

        let pidArgument = pids.sorted().map(String.init).joined(separator: ",")
        guard let lsofOutput = runProcess(executable: "/usr/sbin/lsof", arguments: ["-a", "-d", "cwd", "-p", pidArgument]) else {
            return nil
        }

        return activeSessions(psOutput: psOutput, lsofOutput: lsofOutput)
    }

    public static func activeSessionCounts(psOutput: String, lsofOutput: String) -> [String: Int] {
        activeSessions(psOutput: psOutput, lsofOutput: lsofOutput).reduce(into: [String: Int]()) { result, session in
            result[normalizedPath(session.cwd), default: 0] += 1
        }
    }

    public static func activeSessions(psOutput: String, lsofOutput: String) -> [RunningCodexProcess] {
        let records = processRecords(from: psOutput)
        let recordsByPID = Dictionary(uniqueKeysWithValues: records.map { ($0.pid, $0) })
        let nativeRecords = Dictionary(uniqueKeysWithValues: records
            .filter { isNativeCodexCommand($0.command) }
            .map { ($0.pid, $0) })

        var sessions: [RunningCodexProcess] = []
        for line in lsofOutput.split(separator: "\n", omittingEmptySubsequences: true).map(String.init) {
            let parts = line.split(maxSplits: 8, whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 9,
                  let pid = Int(parts[1]),
                  let nativeRecord = nativeRecords[pid] else {
                continue
            }
            let parentCommand = nativeRecord.ppid.flatMap { recordsByPID[$0]?.command }
            sessions.append(RunningCodexProcess(
                pid: pid,
                cwd: normalizedPath(parts[8]),
                windowTitleHints: terminalTitleHints(
                    nativeCommand: nativeRecord.command,
                    parentCommand: parentCommand
                )
            ))
        }

        return sessions
    }

    public static func nearestAncestorPID(from pid: Int, candidatePIDs: Set<Int>, psOutput: String) -> Int? {
        nearestAncestorPID(from: pid, candidatePIDs: Array(candidatePIDs), psOutput: psOutput)
    }

    public static func nearestAncestorPID(from pid: Int, candidatePIDs: [Int], psOutput: String) -> Int? {
        let recordsByPID = Dictionary(uniqueKeysWithValues: processRecords(from: psOutput).map { ($0.pid, $0) })
        let candidates = Set(candidatePIDs)
        var visited: Set<Int> = []
        var current = pid
        while !visited.contains(current) {
            if candidates.contains(current) {
                return current
            }
            visited.insert(current)
            guard let parent = recordsByPID[current]?.ppid else {
                return nil
            }
            current = parent
        }
        return nil
    }

    public static func normalizedPath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }

    private struct ProcessRecord {
        let pid: Int
        let ppid: Int?
        let command: String
    }

    private static func nativeCodexPIDs(from psOutput: String) -> Set<Int> {
        Set(processRecords(from: psOutput)
            .filter { isNativeCodexCommand($0.command) }
            .map(\.pid))
    }

    private static func processRecords(from psOutput: String) -> [ProcessRecord] {
        var records: [ProcessRecord] = []
        for line in psOutput.split(separator: "\n", omittingEmptySubsequences: true).map(String.init) {
            let parts = line.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(maxSplits: 2, whereSeparator: \.isWhitespace)
                .map(String.init)
            guard parts.count >= 2,
                  let pid = Int(parts[0]) else {
                continue
            }

            if parts.count >= 3, let ppid = Int(parts[1]) {
                records.append(ProcessRecord(pid: pid, ppid: ppid, command: parts[2]))
            } else {
                records.append(ProcessRecord(pid: pid, ppid: nil, command: parts[1]))
            }
        }
        return records
    }

    private static func isNativeCodexCommand(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.hasPrefix("node "),
              !trimmed.contains("ai-traffic-light") else {
            return false
        }

        guard let executable = trimmed.split(whereSeparator: \.isWhitespace).first.map(String.init) else {
            return false
        }
        return executable == "codex" || executable.hasSuffix("/bin/codex")
    }

    private static func terminalTitleHints(nativeCommand: String, parentCommand: String?) -> [String] {
        var hints: [String] = []
        for command in [parentCommand, nativeCommand].compactMap({ $0 }) {
            guard let hint = fnmMultishellID(from: command),
                  !hints.contains(hint) else {
                continue
            }
            hints.append(hint)
        }
        return hints
    }

    private static func fnmMultishellID(from command: String) -> String? {
        let marker = "fnm_multishells/"
        guard let markerRange = command.range(of: marker) else {
            return nil
        }
        let remainder = command[markerRange.upperBound...]
        guard let first = remainder.split(separator: "/", maxSplits: 1).first,
              !first.isEmpty else {
            return nil
        }
        return String(first)
    }

    private static func runProcess(executable: String, arguments: [String]) -> String? {
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
}

public enum RunningProcessCommands {
    public static func fingerprint(_ commands: [String]) -> Int {
        var hasher = Hasher()
        for command in commands.sorted() {
            hasher.combine(command)
        }
        return hasher.finalize()
    }

    public static func snapshot() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "command"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                return []
            }

            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }

            return output
                .split(separator: "\n", omittingEmptySubsequences: true)
                .dropFirst()
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } catch {
            return []
        }
    }
}

public extension ISO8601DateFormatter {
    static var codex: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    static var basic: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    static var withFractionalSeconds: ISO8601DateFormatter {
        codex
    }
}
