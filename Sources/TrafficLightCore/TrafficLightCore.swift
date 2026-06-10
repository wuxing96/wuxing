import Foundation
import CoreGraphics

public enum TrafficLightPanelMode: Equatable, Sendable {
    case collapsed
    case expanded
}

public enum TrafficLightPanelHitRegion: Equatable, Sendable {
    case collapseButton
    case closeButton
    case dragHandle
    case content
}

public enum TrafficLightPanelClickAction: Equatable, Sendable {
    case expand
    case collapse
    case requestClose
    case none
}

public enum TrafficLightPanelInteraction {
    public static let expandedTitleHeight: CGFloat = 52
    public static let expandedCloseButtonSize: CGFloat = 24
    public static let expandedCloseButtonRightMargin: CGFloat = 14
    public static let expandedCloseButtonTopMargin: CGFloat = 16
    public static let expandedWindowButtonSpacing: CGFloat = 8

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
}

public enum TrafficLightRefreshPolicy {
    public static let statusInterval: TimeInterval = 0.25
    public static let tokenUsageInterval: TimeInterval = 30
}

public enum TrafficLightProduct {
    public static let displayName = "Mushi Signal"
}

public enum AgentSource: String, Codable, Equatable {
    case codex = "Codex"
    case claude = "Claude"
}

public enum SessionStatus: String, Codable, Equatable, Hashable, Comparable {
    case inactive
    case completed
    case working
    case waiting

    public var label: String {
        switch self {
        case .inactive:
            return "Idle"
        case .completed:
            return "Done"
        case .working:
            return "Working"
        case .waiting:
            return "Needs you"
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
        case .inactive:
            return 0
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

    public init(
        id: String,
        source: AgentSource,
        projectName: String,
        displayName: String,
        cwd: String,
        status: SessionStatus,
        lastActivity: Date,
        pendingToolCalls: Int,
        summary: String
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
        var latestTimestamp: Date?
        var latestPrimaryUsedPercent: Double?
        var latestPrimaryResetAt: Date?
        var latestPrimaryWindowMinutes: Double?
        var latestSecondaryUsedPercent: Double?
        var latestSecondaryResetAt: Date?
        var latestSecondaryWindowMinutes: Double?

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

            guard latestTimestamp == nil || timestamp >= latestTimestamp! else {
                continue
            }

            let rateLimits = payload["rate_limits"] as? [String: Any]
            let primary = rateLimits?["primary"] as? [String: Any]
            let secondary = rateLimits?["secondary"] as? [String: Any]

            latestTimestamp = timestamp
            latestPrimaryUsedPercent = doubleValue(primary?["used_percent"])
            latestPrimaryResetAt = unixDate(primary?["resets_at"])
            latestPrimaryWindowMinutes = doubleValue(primary?["window_minutes"])
            latestSecondaryUsedPercent = doubleValue(secondary?["used_percent"])
            latestSecondaryResetAt = unixDate(secondary?["resets_at"])
            latestSecondaryWindowMinutes = doubleValue(secondary?["window_minutes"])
        }

        let limitWindowTokens = currentLimitWindowTokens(
            from: tokenEvents,
            now: now,
            resetAt: latestSecondaryResetAt ?? latestPrimaryResetAt,
            windowMinutes: latestSecondaryWindowMinutes ?? latestPrimaryWindowMinutes
        )
        let weekTokens = currentWeekTokens(from: tokenEvents, now: now, calendar: calendar)
        let totalUsedPercent = estimatedUsagePercent(
            tokens: weekTokens,
            totalTokens: limitWindowTokens,
            totalUsedPercent: latestSecondaryUsedPercent ?? latestPrimaryUsedPercent
        )
        let todayUsedPercent = estimatedUsagePercent(
            tokens: todayTokens,
            totalTokens: limitWindowTokens,
            totalUsedPercent: latestSecondaryUsedPercent ?? latestPrimaryUsedPercent
        )

        return TokenUsageSummary(
            totalTokens: weekTokens,
            todayTokens: todayTokens,
            totalUsedPercent: totalUsedPercent,
            todayUsedPercent: todayUsedPercent,
            primaryUsedPercent: latestPrimaryUsedPercent,
            primaryResetAt: latestPrimaryResetAt,
            secondaryUsedPercent: latestSecondaryUsedPercent,
            secondaryResetAt: latestSecondaryResetAt,
            updatedAt: latestTimestamp
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
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }
        return try? parse(
            lines: contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init),
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

public struct CodexSessionStore: Sendable {
    public let root: URL
    public let recentWindow: TimeInterval

    public init(
        root: URL = URL(fileURLWithPath: "\(NSHomeDirectory())/.codex/sessions"),
        recentWindow: TimeInterval = 8 * 60 * 60
    ) {
        self.root = root
        self.recentWindow = recentWindow
    }

    public func loadSessions(now: Date = Date()) -> [AIAgentSession] {
        let runningProcessCommands = RunningProcessCommands.snapshot()
        let activeSessionCountsByCWD = RunningCodexProcesses.activeSessionCounts()
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var sessions: [AIAgentSession] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
            guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate,
                  now.timeIntervalSince(modified) <= recentWindow,
                  let session = CodexSessionParser.parse(fileURL: fileURL, now: now, runningProcessCommands: runningProcessCommands),
                  session.status != .inactive else {
                continue
            }
            sessions.append(session)
        }
        guard let activeSessionCountsByCWD else {
            return sessions
        }
        return Self.filterLiveSessions(sessions, activeSessionCountsByCWD: activeSessionCountsByCWD)
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
        guard let psOutput = runProcess(executable: "/bin/ps", arguments: ["-axo", "pid,command"]) else {
            return nil
        }

        let pids = nativeCodexPIDs(from: psOutput)
        if pids.isEmpty {
            return [:]
        }

        let pidArgument = pids.sorted().map(String.init).joined(separator: ",")
        guard let lsofOutput = runProcess(executable: "/usr/sbin/lsof", arguments: ["-a", "-d", "cwd", "-p", pidArgument]) else {
            return nil
        }

        return activeSessionCounts(psOutput: psOutput, lsofOutput: lsofOutput)
    }

    public static func activeSessionCounts(psOutput: String, lsofOutput: String) -> [String: Int] {
        let pids = nativeCodexPIDs(from: psOutput)
        var counts: [String: Int] = [:]

        for line in lsofOutput.split(separator: "\n", omittingEmptySubsequences: true).map(String.init) {
            let parts = line.split(maxSplits: 8, whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 9,
                  let pid = Int(parts[1]),
                  pids.contains(pid) else {
                continue
            }
            counts[normalizedPath(parts[8]), default: 0] += 1
        }

        return counts
    }

    public static func normalizedPath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }

    private static func nativeCodexPIDs(from psOutput: String) -> Set<Int> {
        var pids: Set<Int> = []

        for line in psOutput.split(separator: "\n", omittingEmptySubsequences: true).map(String.init) {
            let parts = line.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(maxSplits: 1, whereSeparator: \.isWhitespace)
                .map(String.init)
            guard parts.count == 2,
                  let pid = Int(parts[0]),
                  isNativeCodexCommand(parts[1]) else {
                continue
            }
            pids.insert(pid)
        }

        return pids
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
